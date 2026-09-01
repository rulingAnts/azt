# Adversarial verification — corrections

_The verify pass re-checked the four research passes by running the real code._

## XSLT verdict

XSLT for BOTH directions, with a Python driver perimeter — I concur with the xslt-driver agent, and against the "XSLT for export, Python for import" hedge in the brief. Reasoning, per direction:

IMPORT (Dekereke → LIFT): XSLT 1.0 is genuinely adequate and the stylesheet does NOT have to be generated. The per-database column problem is solved by `xsl:param` + `*[name()=$col]`, which I re-verified runs on libxslt 1.1.43; a mapping DOCUMENT (read via `document($mapfile)`) covers the variable-length parts. Nothing in either real sample needs per-column conditional logic, which is the only thing that would force stylesheet generation — and if it ever does, generation buys nothing over direct lxml tree-building and you should switch rather than generate. The honest case for XSLT here is not expressive power, it is (a) reviewability: Kent can read the mapping off the stylesheet, which he cannot off 200 lines of ElementTree calls, and (b) it routes around `addentry`, which is broken TWICE (et.SubElement missing; makenewguid IndexErrors on the empty LIFT a fresh import starts from). Margin over plain lxml tree-building: real but modest.

EXPORT (LIFT → Dekereke): XSLT wins decisively, but only in MERGE mode — identity transform over the ORIGINAL Dekereke file with role-based overrides. That is four templates and loss-free; the Python equivalent is a hand-rolled "copy everything except" walk. Regeneration-from-LIFT is lossy by construction and must be labelled as such in the UI, not shipped as the round-trip path. Two non-negotiables on this side: an existence guard in every override branch (an entry deleted in A-Z+T otherwise blanks the source column), and `xsl:key` + a `for-each` context switch into the secondary document (key() indexes only the current document in XSLT 1.0).

THE CARVE-OUTS ARE HARD, NOT OPTIONAL. Python must own: (1) bytes-in parsing (three live encodings; a pre-decoded str raises), (2) GUID + `datetime.now(UTC).isoformat()[:-7]+'Z'` generation handed over as a side document — lxml rejects node-set params with `TypeError: Argument must be bytes or unicode, got '_Element'`, (3) XML-NAME VALIDATION of the column inventory BEFORE export — I reproduced `XSLTApplyError: xsl:element: The effective name '2ndSpeaker' is not a valid QName`, and that aborts the entire run mid-write, (4) CRLF restoration (XML parsers normalise CRLF→LF; xsl:output has no lever), (5) copying .wav files into `<lift-dir>/audio/`, (6) the mapping dialog.

WHAT THE XSLT PLANS UNDERWEIGHT: none of the actual blockers are XSLT questions. The import stylesheet must satisfy four A-Z+T preconditions I verified by booting the real code — ≥1 gloss per FILE (else IndexError at lift.py:1471), a `citation/form[@lang=analang]` per entry (else sorts silently no-op), ≥1 child element per sense (else the entry is filtered out at lift.py:536), and either a SILCAWL field per sense or the upstream `cawln`→`word_list_n` rename at five sites (else AttributeError at lift.py:678). Those belong in the plan's acceptance criteria, above the XSLT-vs-Python question.

PREREQUISITE, unchanged: `file.gettransformsdir()` is broken (returns an error string; confirmed at runtime). Use `file.pathname_from_base_dir('dekereke_transforms')`; fixing gettransformsdir in the same PR incidentally revives Kent's own XeLaTeX report path.

## Bottom line

The lift-profile pass is the reliable one — I reproduced its three headline defects (addentry/SubElement, Field(ftype=), cawln) and its verification/cvprofile/annotation shapes by driving the live writers, and its two-value model is exactly right. The lift-standard pass is the dangerous one: four of its "what A-Z+T writes" rows are dead code or misreadings (pronunciation, addmodexamplefields/addtoneUF, cvprofile-user_, field type lc/lx), and its "A-Z+T strips empty forms/senses and drops senseless entries" finding is flatly false — clean_lift_tree has no callers and its only invocation is a commented-out __main__ line. Its derived hard constraints ("emit <lexical-unit/> because A-Z+T requires it", "never emit an empty form because A-Z+T strips it") are right-ish advice with false reasons. The xslt-driver pass held up under re-measurement (libxslt 1.1.43, QName abort, node-set param rejection, gettransformsdir dead) and its verdict is correct. The mapping pass's inventories are exact (42/15 columns, empty-Phonetic 0012/0027) but two rows oversell: the tone `_MT` mapping targets fields that hold A-Z+T group names and that nothing reads back, and the `<header><fields>` declaration has no A-Z+T precedent. Four things nobody found, all boot-blockers or diff-noise for the importer: a gloss-less file crashes on open (IndexError, lift.py:1471); sort writes fail silently without a citation analang form (lift.py:2760-2769); sort annotations are shared across senses of an entry (lift.py:3769-3771); and merely opening a file injects empty <citation>/<definition>/<translation> nodes, which any round-trip test must absorb.

## Per-claim corrections

### WRONG: lift-standard: "A-Z+T actively mutates the tree beyond its own additions: it strips empty <form>s and empty <sense>s, and drops entries with no senses" (EV: io_put/lift.py:4755-4781 _clean_removal_reason, :2984-2990) — and the derived hard constraint "Never emit an empty <form> or an empty <sense> — A-Z+T strips them anyway".

Nothing strips anything at runtime. `clean_lift_tree` (io_put/lift.py:4783) and `clean_lift_file` (:4851) have ZERO callers anywhere in the repo; the only invocation is a COMMENTED-OUT snippet in lift.py's `__main__` at :5590-5592 ("Wire __main__ when ready, e.g.: # clean_lift_file(sys.argv[1], ...)"). It is an offline maintenance CLI with `print()` output, not boot/save behaviour. Separately, "drops entries with no senses" is a Python-list filter, not a deletion: io_put/lift.py:536 `self.entries=[i for i in self.entries if len(i.sense)]` — the <entry> stays in the tree and is re-serialised verbatim; it is merely invisible to A-Z+T. Note the filter is `len(i.sense)`, i.e. the CHILD COUNT of the first sense, so `<sense id="x"/>` (attributes only) also makes the entry invisible. Keep the "don't emit empty forms" advice — the real reasons are `checkforsecondchildbylang` (:2776) and `getlang`'s bare `raise` (:2702-2707) — but drop the stated justification.

_evidence:_ grep -rn clean_lift_tree --include=*.py . -> only io_put/lift.py:4783 (def), :4858 (inside clean_lift_file), :5585 (comment). io_put/lift.py:5590-5592 comment block. io_put/lift.py:536.

### WRONG: lift-standard: `<pronunciation>` + `field type="tone"` + `field type="gloss"` + `trait name="location"` is part of "the bounded delta — everything A-Z+T writes", and "is precisely FLEx's own LIFT representation ... will import natively rather than as residue".

A-Z+T never writes <pronunciation> on any live path. `addpronunciationfields` (io_put/lift.py:1113-1155) has exactly one caller, tasks/tasks.py:1279-1287 `def addtonefieldpron(self,guid,framed): #unused; leads to broken lift fn`, whose very next line is `sense=None` followed by `sense.id` (guaranteed AttributeError) and which references an undefined name `check`. The whole <pronunciation> row belongs in the DEAD-CODE column, as lift-profile has it. It is still READ on boot (Entry.getph, :3797) — pass-through only.

_evidence:_ grep -rn "addpronunciationfields" --include=*.py . -> io_put/lift.py:1113 (def), tasks/tasks.py:1280. tasks/tasks.py:1279-1287.

### WRONG: lift-standard's "bounded delta" table lists `addmodexamplefields :777` and `addtoneUF :1069` as things A-Z+T writes; lift-profile's §2 table cites `addmodcitationfields 1108-1112` as a writer of `citation/form`.

All three are dead. `addmodexamplefields`, `addtoneUF` and `addmodcitationfields` have zero callers repo-wide. lift-profile correctly flagged the first two but then cited `addmodcitationfields` as a live writer in its own element table. The only live citation-form writers are `Sense`/`Entry` object paths and `addmediafields` (frontend/sound_ui.py:88).

_evidence:_ grep -rn "addmodexamplefields|addtoneUF|addmodcitationfields" --include=*.py . -> definitions only (io_put/lift.py:777, :1056, :1107). Live callers of the media path: frontend/sound_ui.py:88.

### WRONG: lift-standard: the `<field type=…>` types A-Z+T writes are "lc, lx, tone, location, SILCAWL, cvprofile-user_" (EV :602, :976-1082, :1731, :3285), and "A-Z+T's `type='cvprofile-user_'` (io_put/lift.py:3285) is not FLEx's `cv-pattern`".

Three errors. (a) `cvprofile-user_<ftype>` comes from `cvprofileuservalue` (io_put/lift.py:3280-3294), which has ZERO callers; the live type is `cvprofile_<ftype>` — `return self.fieldvalue('cvprofile_'+ftype,...)` at :3304. I wrote one live and got `<field type="cvprofile_lc">` with `<form lang="fau-x-cvprofile">` and `<form lang="fau-x-cvprofile_MT">`. (b) There is no `<field type="lc">` or `<field type="lx">` element: `entry.fields['lx'|'lc']` are the Lexeme/Citation OBJECTS injected at :3860-3863, not field nodes. (c) The cited :602 is `def verified_groups_by_ps_profile(self,ftype='lc')` — unrelated. The list also omits the entire A-Z+T-private payload: `<profile> <ftype> verification`, `<ftype> primitive verification`, `alphabet verification`, `cvprofile_<ftype>`. lift-profile's inventory is the correct one.

_evidence:_ io_put/lift.py:3280-3294 vs :3295-3309; :3860-3863; :602. Live write on a real LiftXML produced exactly the field types lift-profile lists.

### WRONG: lift-standard: "A-Z+T puts the headword in <citation> but still REQUIRES an (empty) <lexical-unit> element to exist. This is the single most important structural requirement for a Dekereke→LIFT transform" + hard constraint 6 "Emit <lexical-unit/> even though it stays empty".

Not a requirement: A-Z+T CREATES the element when it is missing. `Entry.getlx` (io_put/lift.py:3791) is `Lexeme(self,self.find('lexical-unit'))`; with node=None, `Node.__init__` falls to `parent.append(self)` (:2457) and a fresh empty element is added. Same for `getlc` (:3794), `Sense.getdefinitions` (:3212) and `Example.gettranslations` (:3096). Proven live: I booted an entry that had NO <citation> and the saved file came back with `<citation />` (appended after `</sense>`). Emitting `<lexical-unit/>` is harmless, but it is not the load-bearing requirement; `citation/form[@lang=analang]` is (see next row).

_evidence:_ io_put/lift.py:3791-3796, :2440-2467. Live boot+write of a citation-less entry -> `<citation />` present in output.

### CONFIRMED: mapping + lift-profile: "citation/form[@lang=analang] is the mandatory target / put it anywhere else and the project won't open" (mapping row 2, EV lift.py:1372-1391).

Confirmed, and the failure mode is worse and quieter than described. `collect_and_sort_plausible_lang_codes` (io_put/lift.py:1374-1391) does scan only entry/citation/form + entry/lexical-unit/form + entry/pronunciation/form — so a lexeme-only import still OPENS (analang found in lexical-unit). What then breaks silently is sorting: sort membership is written by `Senses.setitemgroup` (backend/core/lexicon.py:541) -> `annotationvaluebyftypelang('lc',...)` -> `annotationvaluebylang` (lift.py:2760-2769), which on a citation with no analang form only calls `log.error` and returns None — no raise, no write. Reproduced verbatim: `s1-lc has no fau form; can't apply value='k' (only dict_keys([]))`. A lexeme-only Dekereke import therefore opens, looks healthy, and cannot record a single sort. Also note sort annotations hang off the ENTRY's citation form (`Sense.ftypes={'lx':self.entry.lx,'lc':self.entry.lc}`, lift.py:3769-3771), so two senses on one entry SHARE one annotation set — an importer must be one-record-one-entry-one-sense.

_evidence:_ io_put/lift.py:1374-1391, :2760-2769, :3769-3771; backend/core/lexicon.py:541. Live run log line quoted above; with a citation form present the same call wrote `<annotation name="C1" value="k"/>` and `<annotation name="lc" value="CVCVC"/>` inside `citation/form[@lang="fau"]`.

### OVERSTATED: lift-profile: "`getglosslangs` sets annotationlang from glosslangs[0], so a database with no gloss langs has no annotation lang" (and lift-standard/xslt-driver/mapping: gloss is 'required' because entries get dropped / won't display).

Understated, in the dangerous direction: a LIFT with no <gloss> and no <definition> does not degrade, it CRASHES ON OPEN. `getglosslangs` ends `self.annotationlang=self.glosslangs[0]` (io_put/lift.py:1471) over an empty list. It runs at lift.py:68, BEFORE the `if tostrip: return` early-out, so even a template read dies. Reproduced: `IndexError: list index out of range` at io_put/lift.py:1471. Hard rule for the transform: every produced file must carry at least one gloss/definition, in every case — this is a fourth boot-blocker alongside cawln, and no agent stated it.

_evidence:_ io_put/lift.py:68, :1465-1471. Live boot of a gloss-less 1-entry LIFT -> IndexError at :1471.

### CONFIRMED: lift-profile trap 3: "a sense with no SILCAWL number can crash A-Z+T at boot" via `slicebyerror` dereferencing `Sense.cawln` (lift.py:678/684).

Reproduced independently: booting a 1-entry LIFT with a gloss but no SILCAWL field raised `AttributeError: 'Sense' object has no attribute 'cawln'` at io_put/lift.py:678, called unconditionally from `init_post_analang` at io_put/lift.py:87. One addition to the fix scope: `cawln` is dead at FIVE sites, not two — :678, :684, :4620, :4621, :4644 (the last three in the lift-comparison path). `Sense` only ever sets `self.word_list_n` (:3385-3389). A one-line PR is really a five-site rename.

_evidence:_ io_put/lift.py:87, :678, :684, :4620-4621, :4644; grep -rn cawln --include=*.py . Live AttributeError reproduced.

### CONFIRMED: lift-profile trap 1: `LiftXML.addentry` is broken — `et.SubElement` does not exist. / xslt-driver: `makenewguid` IndexErrors on an empty LIFT.

Both true, both on the same code path, and they compound. io_put/lift.py:35 is `from utilities import xmletfns as et`; utilities/xmletfns.py exports only `ElementTree` (:10), `Element` (:11), `parse` (:12) plus readxml/readxmltext/iselement/prettyprint — no `SubElement`. lift.py:345 `et.SubElement(...)` therefore always raises AttributeError. On an EMPTY LIFT the earlier `makenewguid` (:328-329 `allguids=list(self.guids)+list(self.senseids); guid=allguids[0]`) raises IndexError first. So `addentry` is unusable in both the populated and the empty case. Note that lift-standard, mapping and xslt-driver all built their "what A-Z+T writes" tables ON addentry's body as if it ran; the shapes they read off it are still accurate as INTENT, but no file in existence was produced by it.

_evidence:_ io_put/lift.py:35, :328-331, :345-375; utilities/xmletfns.py:10-12. Live caller backend/core/lexicon.py:902.

### CONFIRMED: lift-profile trap 2: `lift.Field(parent, ftype='Plural')` serialises `ftype=` instead of `type=`.

Confirmed by reading, with the useful addition that this is a CALL-SITE bug with a correct idiom already in the file: `FieldParent.fieldvalue` builds fields as `Field(self,node=found,type=type)` (io_put/lift.py:3045), which yields `type=`. Only tasks/tasks.py:175 passes `ftype=`. `Node.tagattrib` (:2414) `attrib=kwargs.pop('attrib',kwargs)` turns the leftover kwarg into the attribute dict; `Field.__init__` (:2954-2957) then reads `self.get('type',kwargs.get('ftype'))`, so the object looks right IN MEMORY and only the reload breaks (`getfields` keys on `node.get('type')`, :2996) — which is why this has survived.

_evidence:_ io_put/lift.py:2404-2419, :2954-2957, :2996, :3045; tasks/tasks.py:175.

### OVERSTATED: mapping row 10/12b: Dekereke `Pitch`/`Surface_Melody`/`Nada` -> `entry/sense/field[@type='tone']/form[@lang='{analang}-x-tone_MT']`; `_Pitch` frame twins -> `example/field[@type='tone']` `_MT` form. "Again _MT only on import."

The `_MT` convention does not mean for tone what it means for cvprofile. (a) `field[@type='tone']` does not hold a tone transcription: at sense level it holds an A-Z+T tone-GROUP NAME `'<ps>_<profile>_<n>'` (backend/core/analysis.py:378-383, `sense.uftonevalue(name)`), and at example level a group value (backend/core/lexicon.py:2128). The plain form is overwritten wholesale the first time tone analysis runs, so importing into it is destructive-on-first-use. (b) Routing to `-x-tone_MT` avoids the clobber but is write-only: grep finds ZERO callers of `uftonevalue(machine=True)` or `Example.tonevalue(machine=True)` anywhere. cvprofile has a real machine->confirmed affirm flow (backend/core/profiles.py:648-655); tone has none. So Dekereke pitch data in `-x-tone_MT` is invisible to every A-Z+T code path. Either park it in a `Dk_Pitch` field and say plainly that A-Z+T ignores it, or claim less for the `_MT` mapping.

_evidence:_ backend/core/analysis.py:378-383, :409-410; backend/core/lexicon.py:2128, :2148; io_put/lift.py:3310-3315, :3065-3070; grep -rn 'machine=True' --include=*.py . (no tone-value callers).

### OVERSTATED: mapping §4c: the Dekereke Reference should be declared in `<lift><header><fields><field tag="Dekereke-Reference">`, "byte-for-byte the shape of A-Z+T's own SILCAWL field (lift.py:4088-4099)" and "A-Z+T already relies on it".

The entry-level `<field type="Dekereke-Reference">` half is sound and A-Z+T tolerates it (`getfieldnames` :1473-1485 is unwhitelisted; `getlang` resolves single-form fields at :2694). The `<header><fields>` half has NO A-Z+T precedent: A-Z+T has zero header/ranges/fields code — `grep -n "'header'|'ranges'|'fields'|range-element" io_put/lift.py` returns nothing, and `LiftURL.lift` raises rather than construct a root (:4152-4154). "A-Z+T already relies on it" is false; the header declaration is purely a FLEx-facing bet, which the doc's own confidence caveat concedes. Note also that A-Z+T will not delete the header — it re-serialises whatever it parsed — so emitting it is safe, just unsupported by the cited evidence.

_evidence:_ io_put/lift.py:4152-4154; grep for header/ranges/fields in io_put/lift.py -> no matches; io_put/lift.py:1473-1485, :2686-2707.

### CONFIRMED: xslt-driver: `file.gettransformsdir()` resolves against `utilities/` and returns an error string, so `xlp.Report.compile()` bails every time; and `getstylesheetdir` "has the same __file__-based fallback bug".

Confirmed at runtime: `gettransformsdir() -> 'HELP! not sure why /Users/Seth/GIT/azt/utilities/xlptransforms is not there!'` while `pathname_from_base_dir('xlptransforms') -> /Users/Seth/GIT/azt/xlptransforms` (exists). io_put/xlp.py:113-116 then logs and returns; xlp.py:75 already says `self.compile() #This isn't working yet.` One nuance: `getstylesheetdir` (utilities/file.py:159-165) is not equally dead — its PRIMARY lookup is `<report-file dir>/xlpstylesheets` and only its fallback carries the `__file__` bug.

_evidence:_ utilities/file.py:159-170; io_put/xlp.py:75, :113-116; runtime output quoted above.

### CONFIRMED: xslt-driver: XSLT 1.0 mechanics — libxslt 1.1.43; `*[name()=$col]` works; `xsl:element name="{$col}"` raises XSLTApplyError on a non-QName; lxml refuses a node-set param.

Reproduced exactly on this machine: LIBXML2 (2,14,4) / LIBXSLT (1,1,43) / LXML (6,0,0,0). `Orth.practice` and `IMP-re` -> valid elements; `2ndSpeaker`, `Speaker 2`, `Tone#` -> `XSLTApplyError: xsl:element: The effective name '...' is not a valid QName.` Node-set param -> `TypeError: Argument must be bytes or unicode, got '_Element'`. NOT re-measured by me: the 187x key()-vs-predicate figure, the merge-blanking demonstration, and the UTF-16 BOM output — all standard XSLT/libxslt behaviour and plausible, but taken on report.

_evidence:_ Direct lxml run in this session; io_put/xlp.py:90-171 for the in-repo idiom.

### CONFIRMED: lift-profile: "No A-Z+T-produced .lift file exists on Seth's machine; every .lift found is a FLEx export" (21 files, all scoring 0 on marker grep).

Confirmed by an independent scan with a wider marker set. One file scores nonzero — /Users/Seth/Documents/WeSay/Kamus_LIFT/Kamus.lift, 284 hits — but ONLY on `Zxxx-x-audio`; it scores 0 on `x-cvprofile`, `verification`, `x-py`, `Latest A-Z+T Sort` and `annotation name`, and opens `<?xml version="1.0" encoding="utf-8"?>` on its own line (i.e. never re-serialised by A-Z+T). That file is useful independent corroboration that `-Zxxx-x-audio` is the real convention in Seth's own WeSay data, against CONTEXT.md:20-24 / ADR 0002 / tests/test_asr_drafts.py:35, which all say `-x-audio`.

_evidence:_ mdfind -name .lift + per-file marker grep, this session; backend/langtags.py:43; io_put/export.py:114 `audiolang='gnd-Zxxx-x-audio'`.

### CONFIRMED: lift-standard: the lift-standard repo's `lift.rng` is the 0.15 draft (field keyed by @name, version fixed to 0.15) and must not be used to validate; 0.13 keys `<field>` by @type.

Fetched and confirmed: https://raw.githubusercontent.com/sillsdev/lift-standard/master/lift.rng fixes `<attribute name="version"><value>0.15</value></attribute>` and its `field-content` requires `<attribute name="name"/>`, not `type`. A-Z+T reads/writes `field[@type=...]` throughout (io_put/lift.py:2996, :3045, :2977-2985). The Ken Zook technical-notes quotations (LiftResidue, FLEx pronunciation mapping, WeSay preservation, additive import) were NOT re-verified in this session — treat them as reported, not audited.

_evidence:_ WebFetch of sillsdev/lift-standard master lift.rng; io_put/lift.py:2977-2996, :3045.

### CONFIRMED: lift-profile: "A-Z+T writes NO XML declaration" (io_put/lift.py:1264) / lift-standard cites the same at :1267.

Confirmed live: a seed file beginning `<?xml version="1.0" encoding="UTF-8"?>` came back beginning `<lift producer="SIL.FLEx 9.1.25.877" version="0.13">` after `db.write()`, fully re-indented at 4 spaces. The correct line is io_put/lift.py:1264 `tree.write(tmp, encoding="UTF-8")` (lift-profile right; lift-standard's :1267 is off by three).

_evidence:_ io_put/lift.py:1240-1264; live boot+write in this session.


## Missed by the research passes
- BOOT MUTATES THE FILE MORE THAN ANY AGENT SAID: simply opening and saving a LIFT injects empty structural elements into every entry/sense/example that lacks them. Live proof — a 1-entry seed came back with `<citation />` (appended AFTER `</sense>`), `<definition />`, and `<translation type="Frame translation" />` that were not in the input. Sources: Entry.getlx/getlc (io_put/lift.py:3791-3796), Sense.getdefinitions (:3212-3214), Example.gettranslations (:3096-3100) — each does `Wrapper(self, self.find(tag))` and Node.__init__ appends a new element when find() returns None (:2440-2467). lift-profile's trap 6 lists only legacy lang rewrites, verification wrapping and duplicate-form deletion. Any 'round-trip is a no-op' test, and any FLEx send/receive diff, must absorb these too.
- A GLOSS-LESS (and definition-less) LIFT CRASHES ON OPEN with IndexError at io_put/lift.py:1471 (`self.annotationlang=self.glosslangs[0]`), called from :68 BEFORE the `tostrip` early-return. Reproduced. This is a fourth hard boot-blocker for imported data, alongside cawln; nobody stated it as a crash.
- THE SORT-ANNOTATION WRITE FAILS SILENTLY (log.error only, no raise, no write) when the entry's <citation> has no analang form: `annotationvaluebylang` io_put/lift.py:2760-2769. Reproduced: `s1-lc has no fau form; can't apply value='k' (only dict_keys([]))`. A lexeme-only Dekereke import opens fine, shows data, and can never record a sort. This is the sharp mechanism behind 'citation is mandatory' — much stronger than the analang-discovery argument, which does NOT actually fail for lexeme-only data.
- SORT ANNOTATIONS ARE PER-ENTRY, NOT PER-SENSE: Sense.ftypes = {'lx': self.entry.lx, 'lc': self.entry.lc} (io_put/lift.py:3769-3771), so all senses of an entry write into the SAME citation form's annotation set. Any importer that ever puts two senses on one entry silently cross-contaminates sort membership. Reinforces one-record → one-entry → one-sense.
- `self.entries=[i for i in self.entries if len(i.sense)]` (io_put/lift.py:536) filters on the CHILD COUNT of the first sense. `<sense id="s1"/>` (no children) makes the whole entry invisible to A-Z+T while remaining in the file. Emit at least grammatical-info + gloss per sense, or records vanish from the UI with no error.
- BOOTING ANY LIFT CAN TRIGGER A NETWORK DOWNLOAD: Sense image-dir resolution does `rootimgdir='images/toselect/'` — a CWD-RELATIVE path — and on absence calls `images.to_select_update.ensure_available()` (io_put/lift.py:3163-3166). In this repo `images/toselect` does not exist, and my first boot attempt hung until timeout. Relevant both to the cawln fix and to any headless test harness for the importer.
- `checkforsecondchildbylang` (io_put/lift.py:2776-2811), which lift-profile correctly flags as a boot-time deleter of duplicate same-lang forms, itself crashes on the shape it is meant to police: line 2792 `if texts and texts[0] == texts[1]` IndexErrors when two same-lang <form>s exist but only one has a <text> child. Another reason the transform must emit exactly one form per (parent, lang).
- `copy_ph_form_and_media_to_lc` (io_put/lift.py:3836-3843) — cited by BOTH lift-profile and lift-standard as the one place `pronunciation/media/@href` is read — has ZERO callers and hard-codes `lang='wmg'`. lift-standard's claim that A-Z+T 'actively migrates media→audio-form' rests entirely on uncalled, single-language dead code. Practical consequence: A-Z+T does not consume `<pronunciation><media href>` at all, so a Dekereke importer that emitted spec-correct media would produce audio A-Z+T can never find.
- `Translation.__init__` (io_put/lift.py:2902-2909) unconditionally does `self.set('type','Frame translation')`. It is safe today only because `gettranslations` looks up `translation[@type="Frame translation"]` specifically — my live run left a pre-existing `<translation type="free">` untouched. But any future code path that wraps an arbitrary translation node will silently retype it. Worth a line in the importer's notes since Dekereke has no translation slot and the transform will be creating these.
- Nobody costed the FLEx round-trip question that lift-profile itself named as the biggest open risk (does FLEx preserve `<annotation>` on `<form>`?). It is testable on Seth's own Windows/FLEx VM and every sort value in the database depends on the answer. It should be sequenced BEFORE the transform design is frozen, not listed as an appendix.