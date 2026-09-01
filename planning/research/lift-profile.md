# Research: lift-profile

_Auto-captured from the 2026-09-02 research workflow. Verified findings only —
see `verify-corrections.md` for what the adversarial pass overturned._

## Summary

A-Z+T emits a *small, non-namespaced, header-less* subset of LIFT 0.13. It never creates a `<lift>` root, `<header>`, `<ranges>`, `note`, `relation`, `variant`, `etymology`, or `reversal` — it re-serialises whatever tree it parsed (`io_put/lift.py:1240-1340`, `tree.write(tmp, encoding="UTF-8")`), so `producer`/`version` and every unknown element pass through untouched but the XML declaration is DROPPED and the whole file is re-indented at 4 spaces. Everything A-Z+T itself writes rides five standard LIFT constructs: `<field type=…>`, `<form lang=…>`, `<annotation name= value=>`, `<trait name= value=>`, and a handful of attributes (`entry@guid/@id/@dateCreated/@dateModified`, `sense@id/@dateModified`, `example@source`, `illustration@href`, `grammatical-info@value`). Its private analysis state is carried entirely by (a) `<annotation>` elements on the analang `<form>` of `<citation>` = the SORT VALUE (group membership), and (b) `<field type="<profile> <ftype> verification">` whose `<form lang="<analang>-x-py"><text>` holds a *Python repr of a list of `check=group` strings* = the VERIFICATION. Glyph/alphabet data is NOT in the LIFT at all (settings file), and syllable slice indices are deliberately kept out (ADR 0001). I generated a real A-Z+T-written file by driving the live writers; it is reproduced verbatim in the artifact. Along the way I confirmed four defects that the Dekereke importer must route around, chief among them that `LiftXML.addentry` — the only "create a new entry" path — is broken.

## Findings

- **[high]** A-Z+T writes NO XML declaration. Its output starts directly with `<lift …>`.
  - _evidence:_ io_put/lift.py:1264 `tree.write(tmp, encoding="UTF-8")` with no `xml_declaration=` argument. CPython's ElementTree emits a declaration only when `encoding.lower() not in ("utf-8","us-ascii","unicode")`. Verified empirically: `python3 -c "...t.write('/tmp/_t.xml',encoding='UTF-8')"` → `b'<lift><entry /></lift>'`. And in my full run the seed file's `<?xml version="1.0" encoding="UTF-8" ?>` line was present before and absent after `db.write()`.

- **[high]** A-Z+T never creates a `<lift>` root, `<header>`, or `<ranges>`; it also never touches note/relation/variant/etymology/reversal. It requires a pre-existing LIFT file and preserves `@producer`/`@version` verbatim.
  - _evidence:_ io_put/lift.py:4152-4154 `def lift(self): raise RuntimeError("LiftURL is trying to make a lift node; this should never happen")`. `grep -rn "'note'|'relation'|'variant'|'etymology'|'reversal'|'ranges'" io_put/lift.py` → no matches. `LiftXML.read` (1170-1178) parses an existing file; there is no create-file path. In my generated output the seed's `<lift producer="SIL.FLEx 9.1.25.877" version="0.13">` survived unchanged.

- **[high]** The audio language tag is `<analang>-Zxxx-x-audio`, NOT `<analang>-x-audio`. CONTEXT.md documents it wrongly.
  - _evidence:_ backend/langtags.py:41-44 — `tone_code='-x-tone'`, `phonetic_code='-x-ipa'`, `audio_code='-Zxxx-x-audio'`, `machine_transcription_code='_MT'`; composed in io_put/lift.py:156-162 `audiolangname`. CONTEXT.md:20-24 says "Equals the base extended code … plus `-x-audio` — for example `en-US-x-kent-x-audio`". My live run printed `audiolang fau-Zxxx-x-audio` and wrote `<form lang="fau-Zxxx-x-audio">`. Detection is a substring test on the full `-Zxxx-x-audio` (lift.py:1382-1384), so a bare `xyz-x-audio` form would NOT be recognised as audio.

- **[high]** Sort-group MEMBERSHIP is stored as `<annotation name="<check>" value="<group>">` children of the analang `<form>` inside `<citation>` (ftype 'lc'). Checks include segmental slots C1/V1/C2/V2…, the syllable primitives `#C`, `C#`, `syls`, and the ftype itself ('lc') carrying the CV-profile sort value.
  - _evidence:_ Writer chain: backend/core/lexicon.py:540-541 `setitemgroup` → `item.annotationvaluebyftypelang(self.ftype,self.analang,check,group)` → io_put/lift.py:3379-3384 → 2760-2769 `annotationvaluebylang` → 2514-2521 `Form.annotationvalue` → `Annotation(self,attrib={'name':name,'value':value})` (lift.py:2488-2493). Primitives written at backend/core/profiles.py:418-423; profile sort value at sorting_engine.py:1107 `annotationvaluebyftypelang(ftype,self.analang,ftype,'')`. ADR 0003 table: "Segmental / tone | `lc` annotation `<check>=<group>`". Confirmed in my generated file.

- **[high]** VERIFICATION is stored in `<field type="<profile> <ftype> verification">` (e.g. `CVCV lc verification`), one `<form lang="<analang>-x-py">` whose `<text>` is the *Python repr of a list of `check=group` strings*, e.g. `['C1=b', 'V1=i', 'C2=s', 'V2=a']`.
  - _evidence:_ io_put/lift.py:3610-3616 `verificationkey` → `f'{profile} {ftype} verification'`; 3617-3650 `verificationtextvalue` stores `str(value)` and reads it back through `xmlfns.stringtoobject` = `ast.literal_eval` (utilities/xmlfns.py:4-8). Form lang from `getlang` (lift.py:2696-2698): `'verification' in self.ftype` → `pylang(analang)` = `analang+'-x-py'` (lift.py:4654). Code shape `check+'='+group` at backend/core/lexicon.py:94-98 `verificationcode`. Codes are split on the LAST '=' because checks are compound (categories.py:47-58).

- **[high]** Two verification field names escape the `<profile> …` pattern: the profile-independent syllable primitives use `"<ftype> primitive verification"`, and alphabet/glyph work uses the bare `"alphabet verification"`.
  - _evidence:_ io_put/lift.py:3608-3616: `PRIMITIVE_VPROFILE='__primitive__'`; `if ftype in ['alphabet','alpha']: return f'{ftype} verification'`; `elif profile==self.PRIMITIVE_VPROFILE: return f'{ftype} primitive verification'`. Live run printed `alphabet key: alphabet verification` and wrote `<field type="lc primitive verification">` holding `['#C=C', 'C#=V', 'syls=2']`.

- **[high]** The CV (syllable) profile lives in `<field type="cvprofile_<ftype>">` with TWO forms: `<analang>-x-cvprofile` = the user-confirmed profile, and `<analang>-x-cvprofile_MT` = the raw machine analysis. Reading must pin the lang; the plain form absent means 'not confirmed' even when the _MT form exists.
  - _evidence:_ io_put/lift.py:4656-4663 `profilelang(analang,machine)`; 3295-3304 `cvprofilevalue` docstring: "reading the plain value returns None when only the _MT form is present (the bug that made unprofiled words look profiled)"; getlang special-case at 2691-2695. Writers: backend/core/profiles.py:329 (`cvprofilemachinevalue`), 503; sorting_engine.py:279, 1106. Confirmed in generated file.

- **[high]** Tone: the SENSE-level underlying-form tone is `<field type="tone"><form lang="<analang>-x-tone">`; the EXAMPLE-level (per-frame) tone is also `<field type="tone">` but the two writers in the tree disagree on the form lang — the live path writes `-x-tone`, the dead legacy path writes glosslangs[0].
  - _evidence:_ io_put/lift.py:3310-3315 `uftonevalue` → fieldvalue('tone') → getlang 2689-2690 `'tone' in self.ftype` → `tonelangname` (147-155) = analang+'-x-tone'. Live example writer: Sense.newexample (3215-3233) → `Example.tonevalue` (3065-3070) → same `-x-tone`. Legacy `addmodexamplefields` (lift.py:874) writes `p.makefieldnode(fieldtype,glosslangs[0],…)` i.e. lang='en'. Group naming `self.ps+'_'+self.profile+'_'+str(x)` at backend/core/analysis.py:380-383.

- **[high]** Alphabet / glyph assignments are NOT stored in the LIFT file — they live in an A-Z+T settings file. Only the per-word `alphabet verification` codes touch the LIFT.
  - _evidence:_ backend/core/alphabet.py:809 and sorting_engine.py:1443 `self.program.settings.storesettingsfile(setting='alphabet')`. `glyph_members()` returns codes of the form `ps_profile_ftype_check_group` (alphabet.py:522-532 `verificationcode`/`parse_verificationcode`), which are resolved back to senses by re-reading `verificationtextvalue` (alphabet.py:405-411).

- **[high]** The syllable slice/page index is deliberately NOT persisted to LIFT (it used to be, as `<annotation name="#C-slice">`).
  - _evidence:_ docs/adr/0001-syllable-slice-index-ephemeral.md: "Keep the slice index session-local (an in-memory dict on `SyllableSliceDict`, `{check: {sense_id: idx}}`), never written to the LIFT" — and its Context table lists the former `<annotation name="#C-slice">` home. Legacy files may still contain `-slice` annotations.

- **[high]** BROKEN: `LiftXML.addentry` — the only code path that creates a new `<entry>` — raises `AttributeError` on every call. This is the path the Dekereke importer would otherwise reuse.
  - _evidence:_ io_put/lift.py:345 `entry=et.SubElement(self.nodes,'entry',attrib={…})`, but `utilities/xmletfns.py` re-exports only `ElementTree`, `Element`, `parse` (lines 10-12) — there is no `SubElement`. Reproduced live: `AttributeError: module 'utilities.xmletfns' has no attribute 'SubElement'. Did you mean: 'Element'?`. Live caller: backend/core/lexicon.py:902 (`addentry(ps='',analang=…,glosslangs=…,form=…)`).

- **[high]** BROKEN: `lift.Field(parent, ftype='Plural')` writes the attribute as `ftype=` instead of `type=`, so a newly created second-form (Plural/Imperative) field is invisible to A-Z+T on the next load.
  - _evidence:_ Call site tasks.py:175 `self.entry.fields[ftype]=lift.Field(self.entry,ftype=ftype)`. `Node.tagattrib` (io_put/lift.py:2404-2420) does `attrib=kwargs.pop('attrib',kwargs)`, so the leftover `{'ftype':'Plural'}` becomes the element's attribute dict. Reproduced live — serialised as `<field ftype="Plural"><form lang="fau"><text>bisabisa</text></form></field>`. `FieldParent.getfields` (2988-3003) keys on `node.get('type')`, which is then None.

- **[high]** BROKEN AT BOOT for CAWL-less data: `LiftXML.slicebyerror` dereferences `Sense.cawln`, an attribute that no longer exists (renamed `word_list_n`). Any sense that ends up with a falsy `imgselectiondir` crashes initialisation — exactly the situation for imported Dekereke data with no SILCAWL numbers.
  - _evidence:_ io_put/lift.py:678 `keys=set([(i.cawln, ', '.join(i.collectionglosses)) …])` and 684 `if i.cawln == k[0]`; `grep -rn cawln` over the repo finds only lift.py:678/684/4620/4621 plus the commented-out lift.py:69 `# self.word_list_n_attr='cawln'`. Sense sets `self.word_list_n` (3385-3389), never `cawln`. Reproduced: booting a LIFT file whose sense had no SILCAWL field → `AttributeError: 'Sense' object has no attribute 'cawln'` at lift.py:678. Adding `<field type="SILCAWL">` to the sense made boot succeed.

- **[high]** Duplicate-form hazard: writing an example's tone through `Example.tonevalue()` when the field's existing form is in a different lang silently ADDS a second `<form>` rather than updating the first.
  - _evidence:_ `FormParent.textvaluebylang` (io_put/lift.py:2730-2743) creates `Form(self,attrib={'lang':lang})` whenever the resolved lang is not already in `self.forms`. Reproduced live on a `<field type="tone"><form lang="en">`: `tone field langs BEFORE: ['en']` → `AFTER: ['en','fau-x-tone']`, serialising both forms. `Field.consolidate_forms_by_lang` (2911-2953) only repairs SAME-lang duplicates, not this.

- **[high]** A-Z+T appends every new child at the END of its parent, so LIFT element order is not maintained (e.g. `<pronunciation>` landed after `<sense>`, and a new `<field>` after `<illustration>`).
  - _evidence:_ io_put/lift.py:2440-2467 `Node.__init__` → `parent.append(self) # add new elements after other children` (with tail-whitespace hygiene). Visible in my generated file: `<pronunciation>` follows `</sense>`, and `<field type="alphabet verification">` follows `<illustration href="bisa.png" />`.

- **[high]** Simply OPENING a LIFT file in A-Z+T mutates it: legacy lang tags are rewritten, legacy verification text is wrapped in form nodes, and some duplicate `<form>` siblings are silently DELETED.
  - _evidence:_ io_put/lift.py:399-413 `legacylangconvert` rewrites `py-xyz` and `xyz-py` form langs to `xyz-x-py`; 467-499 `legacyverificationconvert` moves a verification field's own `.text` into a new `<form lang="<analang>-x-py">`; 2776-2811 `checkforsecondchildbylang` removes the second of two same-lang forms when the texts are equal, or when one path is an absolute version of the other. `Field.consolidate_forms_by_lang` (2911-2953) unions and then deletes duplicate same-lang verification forms, dropping any check whose value conflicts.

- **[high]** The XSLT precedent Kent pointed at is real and in-repo, and there is already a LIFT-specific XSLT to copy the idiom from.
  - _evidence:_ requirements.txt line 21 `lxml`; io_put/xlp.py:92 `import lxml.etree`, :117 `dom=lxml.etree.parse(self.filename)`, :131 `trans=lxml.etree.parse(str(self.transformsdir)+'/'+xslt)`, :136 `transform[n]=lxml.etree.XSLT(trans)` with error-log handling at :137-141, over stylesheets in xlptransforms/. Separately, tools/clean_lift.xsl is an XSLT 1.0 identity-transform stylesheet operating directly on LIFT (de-duplicating trait/sense/gloss/lexical-unit/form, dropping empty forms).

- **[high]** The minimum an imported LIFT record needs for A-Z+T to work with it: a `<citation>` form tagged in the analang, at least one `<gloss>`, and `<sense><grammatical-info value=…>`. Lexeme-only entries and definition-only senses are second-class.
  - _evidence:_ docs/USAGE.md:33-41 — "`citation` forms (Not `lexeme` forms…)", "`gloss`es (Not `definition`s)", "stored in `sense/grammatical-info/@value`", "entries with no lexical category value will be left out of the A-Z+T analysis". Corroborated in code: `Entry.lcvalue` (lift.py:3804-3805) reads the citation; `slicebyps` keys on `psvalue()`; `getglosslangs` (lift.py:1465-1472) sets `annotationlang` from `glosslangs[0]`, so a database with no gloss langs has no annotation lang.

- **[high]** `analang` is inferred, not declared, and a recordings-only import can flip the inference. Priority: settings → filename base → the language of the audio/tone/phonetic forms → any text-form lang → filename base if a valid tag.
  - _evidence:_ io_put/lift.py:1407-1446 `find_plausible_analang` (docstring enumerates the five-step priority); `recorded_analang_candidates` (1393-1406) strips `-Zxxx-x-audio`/`-x-tone`/`-x-ipa` to recover a base tag; `find_plausible_otherlangs` (1447-1464) then builds `audiolang`/`tonelang`/`phoneticlang` as `analang + code`. Live run: `analang fau audiolang fau-Zxxx-x-audio tonelang fau-x-tone phoneticlang fau-x-ipa`.

- **[high]** Audio is attached as a `<form lang="<analang>-Zxxx-x-audio"><text>bare-filename.wav</text></form>` SIBLING of the analang text form (inside `<citation>`, `<lexical-unit>`, a Plural/Imperative `<field>`, or an `<example>`) — NOT via LIFT `<pronunciation><media href=…>`. The files live in `<lift-dir>/audio/`.
  - _evidence:_ Writer: frontend/sound_ui.py:88 `self.program.db.addmediafields(self.node,self.filename,self.program.params.audiolang(),write=False)` → io_put/lift.py:1085-1107, which does `form=Node(node,tag='form',attrib={'lang':lang}); t=form.maketextnode(text=url)`. Resolution: `FormParent.hassoundfile` (lift.py:2873-2890) joins `self.db.audiodir` + the stored relative name; `LiftXML.get_audiodir` (172-188) → `file.getaudiodir` (utilities/file.py:139-143) = `<lift parent dir>/audio`, created if absent. `Entry.copy_ph_form_and_media_to_lc` (3836-3843) is the only place `pronunciation/media/@href` is read, and it only copies the value INTO an audio form.

- **[high]** ASR drafts are stored as annotations on that audio form, namespaced by repo: `{repo}` = transcription, `ipa-{repo}`, `tone-{repo}`, plus `md5` as the staleness key. Digit-named annotations on a form are reserved for revert history.
  - _evidence:_ io_put/lift.py:2522-2594 (ADR 0002 block): `ASR_MD5='md5'`, `ASR_IPA_PREFIX='ipa-'`, `ASR_TONE_PREFIX='tone-'`, `load_drafts`/`wipe_drafts`/`persist_drafts`; "digit names = revert-history, not ASR" (2554). Revert history is written at backend/core/lexicon.py:344-346 and 479-481 (`key=max([int(i) for i in annodict.keys() if i.isdigit()]+[-1])+1`). docs/adr/0002-asr-drafts-as-audio-form-annotations.md. Confirmed in my generated file.

- **[medium]** Round-trip risk for other LIFT tools is concentrated in ONE construct: `<annotation>` on `<form>`. Every A-Z+T sort value and every ASR draft lives there, and form-level annotations are not part of FLEx's own lexical model.
  - _evidence:_ Structural: sort membership is written ONLY as form annotations (lexicon.py:541 → lift.py:2514-2521) and there is no mirror in a field or trait. The verification half is safer — it is a `<field type=…>` with a normal `<form lang=…><text>`, which FLEx imports as a custom field. `docs/USAGE.md:26-28` warns that FLEx's `Export to LIFT` (as opposed to `send/receive for WeSay`) "would preclude sensible sharing back to FLEx in the future". I could not test FLEx's importer from this repo, so the specific claim that FLEx DROPS form annotations is inference from the data model, not observation.

- **[medium]** Every construct A-Z+T writes is schema-legal LIFT 0.13 — `sense`/`example` derive from `extensible` (so `@dateModified` and child `trait`/`field`/`annotation` are allowed), `form` allows `annotation*`, and `example@source` is a defined attribute. The incompatibility is semantic, not syntactic.
  - _evidence:_ Structure observed in the generated file maps onto LIFT 0.13's `extensible` (dateCreated/dateModified attrs; field*/trait*/annotation* children) and `multitext`/`form` (lang attr, text element, annotation*). No file in this repo carries the LIFT RNG/DTD, so this rests on the published LIFT 0.13 spec rather than on a schema I validated against here. Note the semantic strain: `example@source` is a bibliographic reference in LIFT but A-Z+T stores `'AZT sorted first on <timestamp>'` in it (lift.py:3091-3093).

- **[high]** `addmodexamplefields` (lift.py:777), `addtoneUF` (1056) and `addpronunciationfields` (1113) are effectively dead code; do not model the transform on them.
  - _evidence:_ `grep -rn "addmodexamplefields|addtoneUF|addpronunciationfields|addentry(" --include=*.py` outside lift.py returns only tasks.py:1280 and lexicon.py:902. tasks.py:1279 is `def addtonefieldpron(self,guid,framed): #unused; leads to broken lift fn` — the sole caller of `addpronunciationfields`, and it dereferences `sense=None` on the next line. `addmodexamplefields` and `addtoneUF` have no callers at all; `getverificationnode`/`addverificationnode`/`modverificationnode` bodies begin with a bare `raise` (lift.py:456, 501, 513).

- **[high]** No A-Z+T-produced .lift file exists on Seth's machine; every .lift found is a FLEx export. The example in the artifact is one I generated by driving the real writers.
  - _evidence:_ `mdfind -name ".lift"` returned 21 files; scoring each with `grep -c "x-cvprofile|verification|Latest A-Z+T Sort|x-py"` gave 0 for all 21. All inspected headers read `producer="SIL.FLEx 9.x"` (e.g. /Users/Seth/Documents/WeSay/Kamus_LIFT/Kamus.lift, .../Anki Generator/Full Lexicon.lift). No .lift or fixture exists in /Users/Seth/GIT/azt (tests/, data/, lift_templates/ all checked).


## Artifact

ମ# The A-Z+T LIFT Profile

*The exact subset of LIFT 0.13 that A-Z+T writes and consumes. This is the target spec for the Dekereke transform.*

---

## 0. Provenance of the example

No A-Z+T-written `.lift` exists on Seth's disk (all 21 files Spotlight finds are FLEx exports, verified by marker grep). So I **generated one** by importing `io_put/lift.py` and driving the live writers — `annotationvaluebyftypelang`, `verificationtextvalue`, `primitiveverification`, `cvprofilevalue`, `cvprofilemachinevalue`, `uftonevalue`, `addmediafields`, `Form.persist_drafts`, `Sense.newexample`, `Example.lastAZTsort/setguid`, `illustrationvalue`, `addpronunciationfields` — then calling `LiftXML.write()`. The only substitution was a faithful stub for `backend.langtags` (the module needs Python ≥3.12 and this box's default is 3.11); the stub reproduces `backend/langtags.py:41-44` verbatim and `langcodes.tag_is_valid`. Everything below is that file, byte for byte.

---

## 1. Annotated skeleton — a real A-Z+T entry

```xml
<lift producer="SIL.FLEx 9.1.25.877" version="0.13">   ← PASSED THROUGH, never written by AZT.
                                                        ← NOTE: no <?xml …?> line. AZT drops it.
    <entry dateCreated="2026-01-01T00:00:00Z"
           dateModified="2026-09-01T23:17:31.79703Z"    ← touched on every edit (updatemoddatetime)
           guid="11111111-1111-1111-1111-111111111111"
           id="bisa_11111111-…">                        ← id = "<analang form>_<guid>" (addentry only)
        <lexical-unit>                                  ← read; AZT prefers citation
            <form lang="fau"><text>bisa</text></form>
        </lexical-unit>
        <citation>                                      ← ⭐ THE WORKING FORM (ftype 'lc')
            <form lang="fau">                           ← analang. THE data form.
                <text>bisa</text>
                <!-- ▼▼ SORT VALUES (group membership). All of AZT's segmental,
                        primitive and profile sorting lives in these. ▼▼ -->
                <annotation name="C1"   value="b"  />   ← segmental slot checks
                <annotation name="V1"   value="i"  />
                <annotation name="C2"   value="s"  />
                <annotation name="V2"   value="a"  />
                <annotation name="#C"   value="C"  />   ← syllable primitive: word-initial C/V
                <annotation name="C#"   value="V"  />   ← syllable primitive: word-final C/V
                <annotation name="syls" value="2"  />   ← syllable primitive: syllable count
                <annotation name="lc"   value="CVCV"/>  ← name == ftype ⇒ the CV-PROFILE sort value
                <!-- legacy files may also carry name="#C-slice" etc. (ADR 0001: no longer written) -->
                <!-- digit-named annotations (name="0","1",…) = revert history of this form's text -->
            </form>
            <form lang="fau-Zxxx-x-audio">              ← ⭐ AUDIO. Bare filename, no path, no URI.
                <text>fau_bisa_lc.wav</text>            ←   resolves against <lift-dir>/audio/
                <annotation name="mms-fau"      value="bisa"/>  ← ASR draft, keyed by repo
                <annotation name="ipa-mms-fau"  value="bisa"/>  ← ipa-<repo>
                <annotation name="tone-mms-fau" value="LH"  />  ← tone-<repo>
                <annotation name="md5" value="0badc0ffee"/>     ← staleness key for the .wav
            </form>
        </citation>
        <sense id="22222222-…"
               dateModified="2026-09-01T23:16:21.47866Z">       ← AZT adds this even if absent
            <grammatical-info value="Noun" />           ← ⭐ REQUIRED. No value ⇒ sense excluded.
            <gloss lang="en"><text>fish</text></gloss>  ← ⭐ REQUIRED (definitions are 2nd class)
            <definition>
                <form lang="en"><text>a fish</text></form>
            </definition>
            <field type="SILCAWL">                      ← word-list number. See §6 trap 3.
                <form lang="en"><text>0123</text></form>
            </field>
            <field type="cvprofile_lc">                 ← ⭐ CV PROFILE, two forms, never merge them
                <form lang="fau-x-cvprofile">
                    <text>CVCV</text>                   ←   user-CONFIRMED profile
                </form>
                <form lang="fau-x-cvprofile_MT">
                    <text>CVCV</text>                   ←   raw MACHINE analysis
                </form>
            </field>
            <field type="CVCV lc verification">         ← ⭐ VERIFICATION, keyed "<profile> <ftype> verification"
                <form lang="fau-x-py">                  ←   -x-py = "this text is a Python literal"
                    <text>['C1=b', 'V1=i', 'C2=s', 'V2=a']</text>
                </form>                                 ←   repr(list of "<check>=<group>"); split on LAST '='
            </field>
            <field type="lc primitive verification">    ← profile-INDEPENDENT primitive confirmations
                <form lang="fau-x-py">
                    <text>['#C=C', 'C#=V', 'syls=2']</text>
                </form>
            </field>
            <field type="alphabet verification">        ← macrosort/glyph confirmations (bare name)
                <form lang="fau-x-py">
                    <text>['Noun_CVCV_lc_C1_b']</text>  ←   ps_profile_ftype_check_group
                </form>
            </field>
            <field type="tone">                         ← ⭐ UNDERLYING-FORM TONE (sense level)
                <form lang="fau-x-tone"><text>LH</text></form>
            </field>                                    ←   group names: "<ps>_<profile>_<n>"
            <example source="AZT sorted first on 2026-09-01T23:16:21.47884Z">
                <form lang="fau"><text>bisa nai</text></form>   ← frame-substituted form
                <translation type="Frame translation">          ← the ONLY translation @type AZT reads
                    <form lang="en"><text>my fish</text></form>
                </translation>
                <field type="tone">                     ← per-frame tone value / tone group
                    <form lang="fau-x-tone"><text>LH</text></form>
                </field>
                <field type="location">                 ← ⭐ the frame name; the example's KEY
                    <form lang="en"><text>Isolation</text></form>
                </field>
                <trait name="Latest A-Z+T Sort" value="2026-09-01T23:16:21.47884Z"/>
            </example>
            <illustration href="bisa.png" />            ← bare filename, resolves in <lift-dir>/images/
        </sense>
        <pronunciation>                                 ← written only by dead code; read on boot
            <form lang="fau"><text>bisa</text></form>
            <field type="tone"><form lang="en"><text>LH</text></form></field>
            <field type="gloss"><form lang="en"><text>fish</text></form></field>
            <trait name="location" value="Isolation" />
        </pronunciation>
        <field ftype="Plural">   ← ⚠ BUG (§6 trap 2): should be type="Plural"
            <form lang="fau"><text>bisabisa</text></form>
            <form lang="fau-Zxxx-x-audio"><text>…wav</text></form>   ← 2nd-form fields take audio too
        </field>
    </entry>
</lift>
```

**Serialisation facts.** 4-space indent, applied to the WHOLE tree on every save (`xmlfns.indent`, called from `lift.py:1257`). No XML declaration. No namespaces. Attribute order is Python-dict insertion order. Timestamps are `datetime.now(UTC).isoformat()[:-7]+'Z'` (`lift.py:4917-4918`) — note the truncation leaves 5 fractional digits, e.g. `2026-09-01T23:16:21.47866Z`, which is *not* a standard `xs:dateTime` rendering but is what FLEx-origin files already look like after A-Z+T touches them.

---

## 2. Element / attribute table

| Construct | Meaning in A-Z+T | Written by (file:line) | Req. |
|---|---|---|---|
| `lift` | root; `@producer`, `@version` | **never written** — `LiftURL.lift` raises (`io_put/lift.py:4152`) | pass-through |
| `entry@guid` | primary key | `lift.py:345-350` (`addentry`, **broken**) | required |
| `entry@id` | `"<analang form>_<guid>"` | `lift.py:349` | optional |
| `entry@dateCreated` | set once at creation | `lift.py:346` | optional |
| `entry@dateModified` | bumped on every edit | `lift.py:1156-1169` `updatemoddatetime` | optional |
| `lexical-unit/form` | lexeme form; read, rarely written | `Lexeme` `lift.py:2964-2968`; `strip_lxlc_forms` 1359 | optional |
| `citation/form` | **the working form (ftype `lc`)** | `Citation` `lift.py:2969-2973`; `addmodcitationfields` 1108-1112 | **required** |
| `form@lang` | see §3 | `Node.makeformnode` `lift.py:2370-2377`; `textvaluebylang` 2730-2743 | required |
| `form/text` | the value | `Text` `lift.py:2472-2477` (strips `\n`, trims edges) | required |
| `form/annotation@name/@value` | **sort value / group membership**; also ASR drafts, revert history | `Form.annotationvalue` `lift.py:2514-2521` ← `annotationvaluebyftypelang` 3379 ← `Senses.setitemgroup` `backend/core/lexicon.py:540-541` | AZT-private |
| `sense@id` | senseid (a second guid) | `lift.py:364` | **required** |
| `sense@dateModified` | bumped on edit | `lift.py:1159-1161` | optional |
| `grammatical-info@value` | lexical category | `Ps` `lift.py:2498-2501`; `psvalue` 3342-3351 | **required** |
| `gloss@lang` + `gloss/text` | gloss | `Gloss` `lift.py:2897-2901`; `lift.py:373-376` | **required** (≥1) |
| `definition/form` | definition (truncated to 3 words in UI) | `lift.py:367-372` | optional |
| `field@type="SILCAWL"` | word-list number | name from `lift.py:70` `word_list_field_name` | see trap 3 |
| `field@type="cvprofile_<ftype>"` | CV profile, 2 forms | `Sense.cvprofilevalue` `lift.py:3295`, `cvprofilemachinevalue` 3305; `profiles.py:329,503`; `sorting_engine.py:279,1106` | AZT-private |
| `field@type="<profile> <ftype> verification"` | per-word verification codes | `verificationkey` `lift.py:3610-3616`, `verificationtextvalue` 3617-3650; `Categories.modverification` `backend/core/categories.py:26-70` | AZT-private |
| `field@type="<ftype> primitive verification"` | `#C`/`C#`/`syls` confirmations | `primitiveverification` `lift.py:3651-3658`; `profiles.py:410-428` | AZT-private |
| `field@type="alphabet verification"` | glyph/macrosort confirmations | `lift.py:3611`; codes from `alphabet.py:522-528` | AZT-private |
| `field@type="tone"` (sense) | underlying-form tone group | `uftonevalue` `lift.py:3310-3315`; `analysis.py:383` | AZT-private |
| `field@type="tone"` (example) | per-frame tone value | `Example.tonevalue` `lift.py:3065-3070`; `lexicon.py:2130` | AZT-private |
| `field@type="location"` (example) | frame name; the example's key | `Example.locationvalue` `lift.py:3060-3064`; read by `getexamples` 3248-3268 | **required for examples** |
| `field@type="<Plural\|Imperative\|…>"` (entry) | second form; name is user-configured | `tasks.py:175` (**writes `ftype=`, trap 2**); candidate names `settings/__init__.py:156-158` | optional |
| `example@source` | `"AZT sorted first on <ts>"` | `Example.setguid` `lift.py:3091-3093`; also `lift.py:865` | AZT-private |
| `example/form` | frame-substituted form | `Sense.newexample` `lift.py:3215-3233` | required |
| `translation@type="Frame translation"` | the only translation type read | `Translation` `lift.py:2902-2909` (forces `@type` in `__init__`) | required |
| `trait@name="Latest A-Z+T Sort"` (example) | last-sorted timestamp | `Example.lastAZTsort` `lift.py:3084-3090` | AZT-private |
| `trait@name="<ps>-infl-class"` (sense) | inflection subclass | `pssubclassvalue` `lift.py:3316-3328` | optional |
| `trait@name="morph-type"` | read only | alias at `lift.py:4574`; `getmorphtypes` 2211 | pass-through |
| `illustration@href` | bare image filename | `Illustration` `lift.py:3133-3137` (`valuename='href'`), `illustrationvalue` 3463-3474 | optional |
| `pronunciation` | legacy; read on boot | `addpronunciationfields` `lift.py:1113-1155` — **dead** | pass-through |
| `header`, `ranges`, `note`, `relation`, `variant`, `etymology`, `reversal` | untouched | — | pass-through |

---

## 3. Language tags — the complete inventory

Constants: `backend/langtags.py:41-44`.

```python
tone_code                  = '-x-tone'
phonetic_code              = '-x-ipa'
audio_code                 = '-Zxxx-x-audio'   # ← NOT '-x-audio'
machine_transcription_code = '_MT'
```

| Tag | Construction | Where it appears | Source |
|---|---|---|---|
| `fau` (analang) | inferred, see below | `citation/form`, `lexical-unit/form`, `example/form`, 2nd-form fields | `find_plausible_analang` `lift.py:1407-1446` |
| `en` (glosslang) | from data, freq-ordered | `gloss@lang`, `definition/form`, `translation/form`; `glosslangs[0]` becomes `annotationlang` and is the lang for `location`/`SILCAWL` field forms | `getglosslangs` `lift.py:1465-1472` |
| `fau-Zxxx-x-audio` | `analang + audio_code` | audio `<form>` | `audiolangname` `lift.py:156-162` |
| `fau-x-tone` | `analang + tone_code` | `field[@type='tone']/form` | `tonelangname` `lift.py:147-155` |
| `fau-x-tone_MT` | `+ machine_transcription_code` | machine tone | `lift.py:153-154` |
| `fau-x-ipa` | `analang + phonetic_code` | phonetic form | `phoneticlangname` `lift.py:163-171` |
| `fau-x-ipa_MT` | `+ '_MT'` | machine IPA | `lift.py:169-170` |
| `fau-x-cvprofile` | `analang + '-x-cvprofile'` | confirmed profile | `profilelang` `lift.py:4656-4663` |
| `fau-x-cvprofile_MT` | `+ '_MT'` | machine profile | `lift.py:4661-4662` |
| `fau-x-py` | `analang + '-x-py'` | **every** `… verification` field form | `pylang` `lift.py:4654` |
| `py-fau`, `fau-py` | legacy | auto-rewritten to `fau-x-py` on boot | `legacylangconvert` `lift.py:399-413` |

`analang` is **inferred**, never declared in the LIFT: settings → filename base → the base tag recovered from audio/tone/phonetic form langs → most frequent text-form lang → filename base if a valid tag (`lift.py:1407-1446`). `audiolang`/`tonelang`/`phoneticlang` are then built as `analang + code` unless an existing form already carries that code together with the analang (`find_plausible_otherlangs` `lift.py:1447-1464`).

**Doc bug to fix while you're in there:** `CONTEXT.md:20-24` documents audiolang as base `+ '-x-audio'` with the example `en-US-x-kent-x-audio`. The code says `-Zxxx-x-audio`, and detection is a substring test on the *full* code (`lift.py:1382-1384`) — so a form written per CONTEXT.md would not be recognised as audio at all.

---

## 4. Audio and images on disk

| | LIFT stores | Resolves to |
|---|---|---|
| audio | bare `name.wav` in `<form lang="<analang>-Zxxx-x-audio"><text>` | `<dir-of-.lift>/audio/name.wav` — `file.getaudiodir` `utilities/file.py:139-143`, joined in `hassoundfile` `lift.py:2873-2890` |
| images | bare `name.png` in `<illustration href="…">` | `<dir-of-.lift>/images/` (falls back to `pictures/`) — `file.getimagesdir` `utilities/file.py:128-138`, `illustrationURI` `lift.py:3430-3462` |
| reports | — | `<dir-of-.lift>/reports/` — `file.getreportdir` `utilities/file.py:144-148` |

A-Z+T **does not** use `<pronunciation><media href=…>` for recordings. The only place `media/@href` is read is `Entry.copy_ph_form_and_media_to_lc` (`lift.py:3836-3843`), a one-off migration helper that copies the href *into* an audio form. Audio directories are created on boot if absent.

This is a clean fit for Dekereke: Dekereke also stores bare `.wav` names, with the folder in the sibling `<basename>-DkUserSettings.xml` `<sound_file_path>`. **The transform's job is to emit the bare name into a `-Zxxx-x-audio` form and copy/symlink the files into `<output>/audio/`.**

---

## 5. The two-value model (ADR 0003) — what the transform must respect

Every sort type in A-Z+T carries **two independent facts per item**, and conflating them is the bug the ADR was written to prevent:

| Sort type | **Sort value** (membership) | **Verification** |
|---|---|---|
| Segmental (C1/V1/…) | `citation/form[@lang=analang]/annotation[@name='C1']/@value` | code `C1=<group>` inside `field[@type='<profile> lc verification']` |
| Syllable primitives | `annotation[@name='#C'\|'C#'\|'syls']` | code `#C=C` inside `field[@type='lc primitive verification']` |
| Syllable profile | `annotation[@name='lc']/@value` | `field[@type='cvprofile_lc']/form[@lang='fau-x-cvprofile']/text` **matching** that annotation |
| Tone | `field[@type='tone']` (sense = UF group; example = per-frame value) | code in the profile verification field |
| Macrosort / glyphs | glyph→member map in the **settings file**, not the LIFT | `field[@type='alphabet verification']` |

An **imported** database should therefore carry sort values but **no** verification codes — Dekereke's phonetic transcriptions are data, not ear-confirmed A-Z+T sorts. Writing verification codes on import would falsely mark every word as human-confirmed and suppress the very checking A-Z+T exists to do.

---

## 6. Six traps for the Dekereke transform

**Trap 1 — you cannot reuse `addentry`.** `LiftXML.addentry` (`lift.py:333-381`) calls `et.SubElement`, which `utilities/xmletfns.py` does not export (it re-exports only `ElementTree`, `Element`, `parse`, lines 10-12). Every call raises `AttributeError`. Live caller: `backend/core/lexicon.py:902`. **Consequence:** the "add a word" UI path is broken today, and an importer built on it would be too. Build entries with `lift.Node(parent, tag='entry', attrib={…})` (`lift.py:2423-2467`), or — better for an XSLT-driven design — emit the file wholesale and never enter Python at all. *Worth a separate upstream PR; it is a one-line fix (`et.Element` + `parent.append`, or import `SubElement` in xmletfns) and is independent of the Dekereke work.*

**Trap 2 — `lift.Field(parent, ftype='X')` writes the wrong attribute.** `Node.tagattrib` does `attrib=kwargs.pop('attrib', kwargs)` (`lift.py:2414`), so the leftover kwarg lands as an attribute: you get `<field ftype="Plural">`, not `<field type="Plural">`. `getfields` keys on `@type` (`lift.py:2996`), so the field vanishes on reload. Reproduced. In the transform, always write `type=`.

**Trap 3 — a sense with no SILCAWL number can crash A-Z+T at boot.** `slicebyerror` (`lift.py:677-699`) reads `i.cawln`, an attribute renamed to `word_list_n` long ago and now defined nowhere (`lift.py:69` has the rename as a *comment*). It runs for every sense whose `imgselectiondir` is falsy — which is exactly a sense with no word-list number and no matching directory under `images/toselect/`. Reproduced: boot raised `AttributeError: 'Sense' object has no attribute 'cawln'`; adding `<field type="SILCAWL">` made it succeed. **Dekereke data has no CAWL numbers.** Either fix `cawln` → `word_list_n` upstream (trivial, and the right answer), or have the transform emit a `SILCAWL` field. Do not silently invent CAWL numbers — that corrupts the word-list semantics; if you must emit the field to dodge the crash, fix the attribute upstream in the same PR.

**Trap 4 — one `<form>` per lang per parent, or A-Z+T duplicates it.** `textvaluebylang` creates a new `Form` whenever the resolved lang isn't already present (`lift.py:2730-2743`). Reproduced on an example tone field: `['en']` → `['en', 'fau-x-tone']`, both serialised. Verification fields are *especially* fragile — `verificationtextvalue`'s no-lang reads are safe "ONLY because every verification field is single-form" (`lift.py:3621-3626`), and the repair function `consolidate_forms_by_lang` (2911-2953) drops any check whose value conflicts across duplicates. **Emit exactly one form per (parent, lang).**

**Trap 5 — element order is never repaired.** `Node.__init__` appends at the end of the parent (`lift.py:2457`). Anything the transform gets out of order stays out of order forever, and A-Z+T will happily append `<pronunciation>` after `<sense>`. Emit `lexical-unit, citation, pronunciation, sense, field, trait` in that order up front.

**Trap 6 — opening the file mutates it.** Before you diff anything, know that boot alone rewrites `py-xyz`/`xyz-py` form langs to `xyz-x-py` (`legacylangconvert` `lift.py:399-413`), moves verification text from a field into a form node (`legacyverificationconvert` 467-499), and **deletes** same-lang duplicate forms under some conditions (`checkforsecondchildbylang` 2776-2811). A "round-trip produced no changes" test must account for these.

---

## 7. Recommended shape for the transform

Given fact #1 (XSLT, with `lxml` already a dependency and `lxml.etree.XSLT` already used at `io_put/xlp.py:117-141` over `xlptransforms/`), and fact #2 (target only what A-Z+T itself emits):

1. **Encoding is Python's job, not XSLT's.** Hand the raw byte stream to the parser and let it resolve BOM + declaration — Dekereke ships UTF-16LE+BOM, UTF-8+BOM and bare UTF-8 (`/Users/Seth/dekereke-pa-data-source/sample-data/README.md`). Pre-decoding to `str` breaks at least one variant. So: `lxml.etree.parse(open(path,'rb'))` → XSLT → serialise.
2. **Column names are per-database, so the stylesheet needs a mapping parameter.** `<data_form>` child element names *are* user-defined column names. Pass the Dekereke-column → LIFT-target map in as XSLT parameters (or generate a tiny per-database stylesheet), rather than hard-coding `Phonetic`/`Gloss`.
3. **Emit only §2's "required" rows plus what the data actually supports:** `entry@guid` (generate v4), `citation/form[@lang=analang]/text` ← Dekereke `Phonetic`; `sense@id` (generate); `grammatical-info@value` ← the part-of-speech column, or a single configured default (a sense with no value is silently dropped); `gloss[@lang=glosslang]/text` ← the gloss column; `form[@lang='<analang>-Zxxx-x-audio']/text` ← the bare `.wav` name. Skip records with an empty `Phonetic` (the README flags one such record in `SampleLang_full.xml`); ignore `<qvp_acoustic_data_>` blocks.
4. **Write sort values, never verification codes** (§5). If the Dekereke database carries a usable tone column, it maps to `field[@type='tone']/form[@lang='<analang>-x-tone']` at *sense* level (UF tone) — but the safer default is to land it in a plain custom field and let the linguist sort it in A-Z+T, since the whole point of A-Z+T is the ear-check.
5. **Do emit an `<?xml … ?>` declaration** in the transform's output even though A-Z+T will strip it on first save. It costs nothing and every other LIFT tool expects it.
6. **Copy the `.wav` files** named in the database from the `<sound_file_path>` in the sibling `-DkUserSettings.xml` into `<output-dir>/audio/`, keeping bare names.
7. **Model the code on `tools/clean_lift.xsl`** — it is already an XSLT 1.0 identity-transform stylesheet over LIFT, in-repo, with the invocation both via `xsltproc` and via `lxml` documented in its header comment. Kent will recognise the idiom.

**Suggested upstream split:** (a) the three one-line defect fixes — `xmletfns.SubElement`, `Field(ftype=)` → `type=`, `cawln` → `word_list_n` — as a small standalone PR that stands on its own merits; (b) the Dekereke importer as a separate feature PR that depends on it. Kent is far more likely to merge the second once the first has landed and the first is much easier to review in isolation.

---

## 8. What I could not determine

- **FLEx's actual treatment of `<annotation>` on `<form>`.** Every A-Z+T sort value and ASR draft lives there, and it is the single point of failure for a FLEx round-trip. LIFT 0.13 permits it; whether FLEx's importer *preserves* it is not answerable from this repo. `docs/USAGE.md:26-28` hints at trouble ("`Export to LIFT` … would preclude sensible sharing back to FLEx"). **This is worth an empirical test on the Windows/FLEx VM before committing the transform's design** — if FLEx drops them, a FLEx round-trip silently destroys every sort in the database, and that is a much bigger finding than anything in this document.
- **Whether A-Z+T's `.lift` output validates against the LIFT 0.13 RNG.** No schema ships in this repo. Everything I saw looks schema-legal by the published spec, but I did not validate.

## Open questions
- Does FLEx's LIFT importer preserve `<annotation name= value=>` children of `<form>`? Every A-Z+T sort value and every ASR draft lives there. If FLEx drops them, a FLEx round-trip silently destroys the entire sort state of a database — a bigger issue than the Dekereke import itself. Testable on the Windows/FLEx VM with the generated sample in §1.
- Should the Dekereke transform emit a `SILCAWL` field purely to dodge the `cawln` boot crash (trap 3), or should `slicebyerror` be fixed upstream first? Emitting fake word-list numbers corrupts CAWL semantics; the upstream fix is a two-token rename. Recommend the fix.
- Which Dekereke column becomes `grammatical-info@value`? A-Z+T silently EXCLUDES any sense with no lexical category (docs/USAGE.md:41), so a Dekereke database with no POS column would import as a lexicon A-Z+T cannot analyse at all. Does Seth's Fayu database have one, or does the transform need a configured constant?
- Does Fayu tone data in Dekereke map onto A-Z+T's sense-level UF `field[@type='tone']` (group names `<ps>_<profile>_<n>`, analysis.py:380-383), or should it land in a neutral custom field and be sorted inside A-Z+T? The two-value model (ADR 0003) argues for the latter, but Seth's existing Dekereke tone marking may already be an analysis worth carrying over.
- Should the three defect fixes (`xmletfns.SubElement`, `Field(ftype=)`, `cawln`) go upstream as a separate PR before the importer? They are independent of the Dekereke work and all three are one-liners, but two of them (addentry, cawln) mean Kent may be unaware that adding a word and opening a CAWL-less database are both broken today.
- Is `example@source` (currently `'AZT sorted first on <ts>'`, lift.py:3091-3093) worth flagging upstream? LIFT defines `@source` as a bibliographic reference; A-Z+T's use is schema-legal but semantically wrong, and it is the kind of thing that would bite a future interop effort.