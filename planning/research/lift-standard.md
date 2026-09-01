# Research: lift-standard

_Auto-captured from the 2026-09-02 research workflow. Verified findings only —
see `verify-corrections.md` for what the adversarial pass overturned._

## Summary

LIFT's live version is **0.13** (0.15 exists on paper only; Ken Zook, FLEx technical notes, 2026-02-10: "Although version 0.15 has been defined, at this point programs are all using version 0.13"). Authoritative artifacts: https://github.com/sillsdev/lift-standard (`lift_13.pdf`, `lift.rng`=0.15) and the schema FLEx actually validates against, `lift-0.13.rng`, embedded in `SIL.Lift.dll` and mirrored at https://raw.githubusercontent.com/sillsdev/libpalaso/master/SIL.Lift/Validation/lift-0.13.rng.

The answer to Seth's million-dollar question is narrower and better than expected: **A-Z+T does not author LIFT — it round-trips it.** `LiftXML.read()` (io_put/lift.py:1170-1179) parses the whole file with `xml.etree.ElementTree.parse`, and `write()` (:1240-1358) re-indents and re-serialises *that same tree*. There is no LIFT-writer, no serialiser, no `<lift>` root constructor, and no `<header>`/`<ranges>`/`<fields>` code path anywhere in the repo. So "LIFT that A-Z+T produces" = "LIFT that A-Z+T was given (WeSay/FLEx export), plus a small, enumerable set of added nodes." Those added nodes are: `<entry>`/`<lexical-unit>`/`<citation>`/`<sense>`/`<grammatical-info>`/`<definition>`/`<gloss>` (`addentry`, :333-380); `<pronunciation>` with `<field type="tone">`, `<field type="gloss">`, `<trait name="location">` (`addpronunciationfields`, :1113-1155); `<field type=…>` bookkeeping (`lc`, `lx`, `tone`, `location`, `SILCAWL`, `cvprofile-user_`); `<form lang="…-Zxxx-x-audio|-x-tone|-x-ipa|_MT">`; and `<annotation name= value=>` on forms (ADR 0002).

Two decisive alignments: (1) A-Z+T's `<pronunciation>` shape is **byte-for-byte FLEx's own** pronunciation mapping (`field type="tone"`, `trait name="location"` — Zook §5 Pronunciation), so it is native data, not private bookkeeping; (2) A-Z+T's audio convention **is** the WeSay/FLEx `xxx-Zxxx-x-audio` form-based hack, not the spec's `<pronunciation><media href>` — `backend/langtags.py:43` sets `audio_code='-Zxxx-x-audio'`, and `Entry.copy_ph_form_and_media_to_lc` (io_put/lift.py:3836-3843) literally *reads* a `<media href>` and *rewrites* it as a citation audio form. A-Z+T never writes a `<media>` element.

Round-trip survival is good: FLEx stores anything it can't model as `LiftResidue` and re-emits it on export ("LIFT imports attempt to store any data from the LIFT file that cannot be stored in normal FieldWorks objects so that a LIFT export will return the unused data"), and WeSay "should not lose any LIFT data, but it will only allow you to edit parts it understands." A-Z+T's `<annotation>` ASR drafts have no FLEx model mapping and will survive as opaque residue, not as editable fields.

## Findings

- **[high]** The current, universally-used LIFT version is 0.13. Version 0.15 is defined but no program uses it. The RelaxNG that FLEx actually validates against is lift-0.13.rng, embedded in SIL.Lift.dll.
  - _evidence:_ Ken Zook, "Technical Notes on LIFT used in FLEx" (2026-02-10), §1: "Although version 0.15 has been defined, at this point programs are all using version 0.13." §10: "The Relax NG XML Schema (lift-0.13.rng) file is embedded in SIL.Lift.dll in the FieldWorks program directory and is used for validating LIFT files." PDF: https://downloads.languagetechnology.org/fieldworks/Documentation/Technical%20Notes%20on%20LIFT%20used%20in%20FLEx.pdf . Repo README (https://github.com/sillsdev/lift-standard): "The most recent published version is 0.13". FLEx UI help page confirms export is "Full Lexicon LIFT 0.13 XML" (https://downloads.languagetechnology.org/fieldworks/Documentation/en/User_Interface/Menus/File/Export/Export_full_lexicon_(LIFT).htm). Note the repo's own lift.rng is the 0.15 draft — do NOT validate against it.

- **[high]** A-Z+T has no LIFT writer. It parses an existing LIFT file into one ElementTree and writes that same tree back. Therefore the "LIFT A-Z+T produces" is entirely determined by the LIFT it was handed, plus a small enumerable set of added nodes.
  - _evidence:_ io_put/lift.py:1170-1179 `read()` → `et.readxml(self.filename)` → `utilities/xmletfns.py:15-18` `ET.parse(filename); tree.getroot()`. io_put/lift.py:1240-1358 `write()` → `xmlfns.indent(self.nodes); tree=et.ElementTree(self.nodes); tree.write(tmp, encoding="UTF-8")`. Repo-wide `grep -n "'header'|'ranges'|'fields'|range-element|lift-ranges" io_put/lift.py utilities/xmletfns.py` returns ZERO matches. `io_put/lift.py:2468-2471` class `Lift(Node)` merely wraps the already-parsed root; nothing constructs a `<lift>` element.

- **[high]** A-Z+T writes LIFT files with NO XML declaration, because `tree.write(tmp, encoding="UTF-8")` suppresses it in CPython's ElementTree.
  - _evidence:_ io_put/lift.py:1267 `tree.write(tmp, encoding="UTF-8")` with no `xml_declaration=` argument. Verified empirically on this machine: `ET.ElementTree(ET.fromstring('<lift version="0.13"><entry/></lift>')).write(buf, encoding='UTF-8')` yields `b'<lift version="0.13"><entry /></lift>'` — no `<?xml ...?>`. CPython emits a declaration only when `encoding.lower()` is not in ("utf-8","us-ascii","unicode"). This is still legal XML (UTF-8 is the default), and FLEx's minimal example does include `<?xml version="1.0"?>` (Zook §1), so a Dekereke→LIFT transform should emit one; but A-Z+T will strip it on the first save.

- **[high]** A-Z+T uses the WeSay/FLEx de-facto audio convention (`<form lang="xxx-Zxxx-x-audio"><text>file.wav</text></form>`), NOT the spec-sanctioned `<pronunciation><media href=…/>`. It reads `<media>` but never writes one, and actively migrates media→audio-form.
  - _evidence:_ backend/langtags.py:43 `audio_code='-Zxxx-x-audio'`; io_put/lift.py:156-162 `audiolangname()` returns `analang + audio_code`. io_put/export.py:~110 real-world invocation `audiolang='gnd-Zxxx-x-audio'` against `/home/kentr/Assignment/Tools/WeSay/gnd/gnd.lift`. Only `<media>` reference in the whole module is a READ: io_put/lift.py:3838 `wav=self.ph.find('media').get('href')`, inside `copy_ph_form_and_media_to_lc` (:3836-3843), which then writes `self.lc.textvaluebylang(lang=self.db.audiolang, value=wav)` — i.e. converts a spec `<media href>` into an audio `<form>` under `<citation>`. `addmediafields` (:1085-1105) is a misnomer: it creates `Node(node, tag='form', attrib={'lang':lang})` with the filename as text. FLEx's own doc endorses the same hack: "<form lang=\"fr-Zxxx-x-audio\"><text> 638277086107188840test.wav</text></form>" (Zook §5, Lexeme Form), "Audio or video files can be referenced using a special audio writing system. Only one file can be included in the audio writing system." `Zxxx` is ISO 15924 for unwritten documents.

- **[high]** A-Z+T's docs contradict its code on the audio tag. CONTEXT.md and ADR 0002 both say `-x-audio`; the code says `-Zxxx-x-audio`. The docs are wrong.
  - _evidence:_ /Users/Seth/GIT/azt/CONTEXT.md:20-24 "Equals the base extended code (with any private-use dialect subtags) plus `-x-audio` — for example `en-US-x-kent-x-audio`". /Users/Seth/GIT/azt/docs/adr/0002-asr-drafts-as-audio-form-annotations.md uses `<analang>-x-audio` and `<form lang="gnd-x-audio">` throughout. /Users/Seth/GIT/azt/tests/test_asr_drafts.py:35 also uses `{'lang': 'nml-x-audio'}`. But backend/langtags.py:43 is `audio_code='-Zxxx-x-audio'` and io_put/export.py's `__main__` block uses `'gnd-Zxxx-x-audio'`. The tests construct their own fixture strings and so never exercise the real constant.

- **[medium]** A-Z+T's audiolang construction produces a malformed BCP-47 tag whenever the analang carries a private-use subtag — directly relevant to Fayu (iau_tmu).
  - _evidence:_ io_put/lift.py:156-162: `bits=[lang if lang else self.analang, langtags.audio_code]; return ''.join(bits)` — naive concatenation. With analang `iau` → `iau-Zxxx-x-audio` (well-formed: language + ISO-15924 script + private-use). With a dialect-tagged analang such as `iau-x-tmu` → `iau-x-tmu-Zxxx-x-audio`, which is NOT well-formed BCP-47: a script subtag cannot follow a private-use section, and two `x-` singletons cannot appear. CONTEXT.md:20-24 explicitly describes analangs that carry "private-use dialect subtags", so this is a live hazard, not hypothetical. Same naive-concat pattern in `tonelangname` (:147-155) and `phoneticlangname` (:163-171) for `-x-tone`/`-x-ipa`.

- **[high]** A-Z+T's `<pronunciation>` output is not private bookkeeping — it is precisely FLEx's own LIFT representation of the FLEx Pronunciation object, and will import natively rather than as residue. The one exception is `<field type="gloss">`.
  - _evidence:_ io_put/lift.py:1129-1135 writes `<pronunciation><form lang=analang>` + `makefieldnode(type=fieldtype /*'tone'*/, lang=glosslangs[0])` + `makefieldnode(type='gloss', lang=…)` + `maketraitnode(type='location', value=…)`; docstring at :1144-1153 shows the exact target XML. Zook §5 Pronunciation: "Tone: stored in a field element with a tone type attribute"; "CV Pattern: stored in a field element with a cv-pattern type attribute"; "Location: A single location is stored in a location trait with the string in a value attribute. Locations are referenced to items in the Locations list." Enumerating every `field type=` in Zook's doc gives: import-residue, tone, summary, scientific-name, preccomment, note, literal-meaning, languagenotes, exemplar, cv-pattern, comment, bibliography. `gloss` is NOT among them, so A-Z+T's `<field type="gloss">` inside `<pronunciation>` is A-Z+T-only and becomes LiftResidue. Likewise A-Z+T's `type='cvprofile-user_'` (io_put/lift.py:3285) is not FLEx's `cv-pattern`.

- **[high]** FLEx does NOT drop unknown <field>/<trait>/<annotation> on import: it stores them in a LiftResidue field and re-emits them on export. WeSay likewise preserves but cannot edit them.
  - _evidence:_ Zook §8 ("Preparing LIFT data" / LiftResidue): "LIFT imports attempt to store any data from the LIFT file that cannot be stored in normal FieldWorks objects so that a LIFT export will return the unused data. This is an attempt to never lose additional information that other programs need when using LIFT. FLEx does this by storing LiftResidue fields that will never get deleted via the user interface." Sample shown as `<LiftResidue><Uni>&lt;lift-residue id=…&gt;…</Uni></LiftResidue>`. Separately there is a first-class `<field type="import-residue">` on entry and sense (Zook §5, §6). Zook §9: "WeSay does not support many of the more advanced features of the FLEx dictionary model. For areas it doesn't support, it should not lose any LIFT data, but it will only allow you to edit parts it understands." Caveat: FLEx File…Import…LIFT is strictly ADDITIVE — "You can add new information or modify some existing fields, but you can't remove fields that are already in the FLEx project." Deletion only via `dateDeleted` on `<entry>`, or via Send/Receive.

- **[high]** <annotation> has no FLEx model mapping at all, so A-Z+T's ASR-draft annotations (ADR 0002) survive a FLEx round trip only as opaque LiftResidue — never as editable FLEx data.
  - _evidence:_ Grepping the entire 46-page Zook document for "annotation" yields exactly two kinds of hit: (a) "Preceding Annotation: stored in a field element with a preccomment type" — an etymology field, unrelated; (b) occurrences inside the verbatim lift-0.13.rng reproduced in §10. The FLEx-mapping body never maps `<annotation>` to any FLEx object. Combined with the LiftResidue guarantee above, this means preservation without comprehension. A-Z+T writes these at io_put/lift.py:2155 `Node(form, tag='annotation', **anndict)` and 2572-2594 (`persist_drafts`), per docs/adr/0002-asr-drafts-as-audio-form-annotations.md.

- **[high]** The .lift-ranges sidecar holds the controlled vocabularies (semantic domains, POS, locations, statuses) that <trait> and <grammatical-info> values point into. A-Z+T neither reads nor writes it, and FLEx auto-creates missing list items on import.
  - _evidence:_ Zook §2 Ranges: "Range definitions can be stored directly in the LIFT file, but FLEx stores the definitions in a separate .lift-ranges file." `<range id="status" href="file://…/TLP.lift-ranges"/>` in the LIFT `<header><ranges>`; the sidecar root is `<lift-ranges>` holding `<range id=…><range-element id=… guid=…><label>/<abbrev>/<description>`. "Note that on import into FLEx, any references to range elements in senses and entries will try to find an existing item in the FLEx list. If not found, a new item will be added to the FLEx list, and the Import Log file will list the fact that a new item has been added to the list." Full project layout (Zook §1): the .lift file, a .lift-ranges file, a WritingSystems folder of .ldml, a "pictures" folder, an "audio" folder — "Everything other than the LIFT file are optional." A-Z+T: zero code references (see finding 2).

- **[high]** `<field>` is keyed by @type in LIFT 0.13 but by @name in the 0.15 draft. A-Z+T (and FLEx) use @type. A transform must not follow the repo's lift.rng.
  - _evidence:_ lift-0.13.rng `field-content`: `<interleave><ref name="multitext-content"/><ref name="extensible-without-field-content"/></interleave><attribute name="type"/>` with a Schematron assert "There is only one field with a given type allowed in any parent element." The 0.15 `lift.rng` at https://raw.githubusercontent.com/sillsdev/lift-standard/master/lift.rng defines field-content with a required `@name` instead, and its `lift-content` fixes `@version` to "0.15". A-Z+T reads/writes `field[@type=…]` throughout (e.g. io_put/lift.py:1731 `asense.find("field[@type='SILCAWL']")`, :2977-2985 `checkforsecondfieldbytype`).

- **[high]** A-Z+T actively mutates the tree beyond its own additions: it strips empty <form>s and empty <sense>s, and drops entries with no senses. A Dekereke transform must therefore never emit empty placeholder forms.
  - _evidence:_ io_put/lift.py:4755-4781 `_clean_removal_reason` — removes "an EMPTY <form> (no <text> content and no annotation)", "an empty <sense> (safety net)", and a lexical-unit `<form>` whose lang duplicates a gloss/definition lang (Rule 3); protected from removal are forms whose lang contains any of `_CLEAN_PROTECTED_CODES` = (`-Zxxx-x-audio`, `-x-ipa`, `-x-tone`, `_MT`) (:4678-4680) and forms inside a `<field>`. io_put/lift.py:2984-2990 `Entry.getsenses`: logs "Removing entry with no senses" and returns 1. This matters because Dekereke's empty fields are self-closing elements (per /Users/Seth/dekereke-pa-data-source/sample-data/README.md) — the natural naive mapping would emit exactly the empty forms A-Z+T deletes.

- **[high]** A-Z+T puts the headword in <citation>, not <lexical-unit>, but still requires an (empty) <lexical-unit> element to exist. This is the single most important structural requirement for a Dekereke→LIFT transform aimed at A-Z+T.
  - _evidence:_ io_put/lift.py:351-362, `addentry`: `lexicalunit=et.SubElement(entry,'lexical-unit',attrib={})` with the comment "Just adding citation, not lexeme forms, with this function, though we need the lexeme field (above) to be there"; the form-writing lines for lexical-unit are commented out (:354-356); the headword text goes to `citation/form[@lang=analang]/text` (:359-362). `Entry.getlx` (:2990-2993) does `Lexeme(self, self.find('lexical-unit'))` unconditionally. Entry attributes written: `dateCreated`, `dateModified`, `guid`, `id` (= `form + '_' + guid`); sense attribute: `id` (:345-364).

- **[high]** The XSLT precedent Kent suggested is real and adds no dependency: lxml is already a hard requirement and lxml.etree.XSLT already runs a 4-stage chained pipeline in-repo.
  - _evidence:_ /Users/Seth/GIT/azt/requirements.txt line 21 `lxml` (bare, unconditional). /Users/Seth/GIT/azt/io_put/xlp.py:90-171 `compile()`: `import lxml.etree`, `dom=lxml.etree.parse(self.filename)`, then for each of `XLingPapRemoveAnyContent.xsl`, `XLingPapXeLaTeX1.xsl`, `XLingPapPublisherStylesheetXeLaTeX.xsl`, `TeXMLLike.xsl`: `trans=lxml.etree.parse(str(self.transformsdir)+'/'+xslt); transform[n]=lxml.etree.XSLT(trans)`, applied as `newdom=transform[1](dom)` … `newdom.write_output(outfile+'a')`, with `transform[n].error_log` drained to the app log. Stylesheets live in /Users/Seth/GIT/azt/xlptransforms/ and are located via `file.gettransformsdir()`. Note lxml is imported lazily inside `compile()` with an ImportError fallback (xlp.py:91-95), and io_put/lift.py deliberately does NOT use lxml (lift.py:7-16 forces `lxml=False` and uses stdlib `xml.etree`).

- **[high]** Dekereke's column inventory maps cleanly onto only part of A-Z+T's LIFT vocabulary; several columns have no A-Z+T-side home and several collide with LIFT's one-form-per-lang rule.
  - _evidence:_ Parsing /Users/Seth/dekereke-pa-data-source/sample-data/SampleLang_full.xml (root `<phon_data>`, 10 `<data_form>` records) gives per-record children: Reference, Gloss, IndonesianGloss, Category, Type, SyllableProfile, Phonetic, Pitch, {CMPLalt,INCMP,IMP-re,SVC,SEQ}(+_Pitch twins), Notes, SoundFile (`0003_tree.wav`), frame columns goodX/whiteX/Xbad/Xneg/pigX/Xpig/Xwater (+_Pitch twins), Phonemic, Orth.practice, VerbClass, Orthography, Surface_Melody, SpeakerA, Tulisan, Nada, Inflection_Class, qvp_acoustic_data_. Phonetic/Phonemic/Orthography/Tulisan/SpeakerA are four-plus renderings of the same headword: LIFT's `multitext-content` Schematron forbids more than one `<form>` with a given `@lang` in one parent, so they cannot all be `lang="iau"` — they need distinct writing-system tags (e.g. `iau-fonipa`, `iau-Latn`) or distinct parents.


## Artifact

# LIFT 0.13 Reference Card — scoped to what A-Z+T reads and writes

## 0. Canonical sources (use these, not the repo's `lift.rng`)

| What | URL |
|---|---|
| Standard repo | https://github.com/sillsdev/lift-standard |
| **Spec, current version (0.13)** | https://github.com/sillsdev/lift-standard/blob/master/lift_13.pdf |
| 0.14 / 0.15 specs (defined, unused) | `lift_14.pdf`, `lift_15.pdf` in the same repo |
| `lift.rng` in that repo | **0.15 — do NOT validate against it** (`<value>0.15</value>`, `field/@name`) |
| **The RNG FLEx actually validates with** | https://raw.githubusercontent.com/sillsdev/libpalaso/master/SIL.Lift/Validation/lift-0.13.rng (embedded in `SIL.Lift.dll`; reproduced verbatim in Zook §10) |
| Migration XSLTs | `LIFT-0.13-0.14.xsl`, `LIFT-0.14-0.15.xsl` |
| **FLEx's mapping of LIFT (the real behavioural doc)** | https://downloads.languagetechnology.org/fieldworks/Documentation/Technical%20Notes%20on%20LIFT%20used%20in%20FLEx.pdf — Ken Zook, 2026-02-10, 46 pp. |
| FLEx export UI help | https://downloads.languagetechnology.org/fieldworks/Documentation/en/User_Interface/Menus/File/Export/Export_full_lexicon_(LIFT).htm |

**Version:** emit `<lift version="0.13">` literally. The 0.13 RNG pins it with `<value>0.13</value>`; anything else fails FLEx's validator. `@producer` is the only other root attribute (optional). Zook §1: *"Although version 0.15 has been defined, at this point programs are all using version 0.13."* and *"It's unlikely that SIL will pursue further development of LIFT."*

**Project layout** (Zook §1): `X.lift` + `X.lift-ranges` + `WritingSystems/` (`.ldml`) + `pictures/` + `audio/`. *"Everything other than the LIFT file are optional."* All content is **UTF-8, NFC**.

---

## 1. The multitext / form / text model

```
multitext-content ::= zeroOrMore <form lang=…>          ← at most ONE form per @lang per parent (Schematron)
form-content      ::= @lang (required) + form-no-lang-content
form-no-lang      ::= <text> (exactly one) & zeroOrMore <annotation>
span-content      ::= mixed text & zeroOrMore <span lang? href? class?>   (recursive)
```

`<gloss>` is the trap: it uses **`form-content`**, i.e. `@lang` sits on `<gloss>` itself —
`<gloss lang="en"><text>tree</text></gloss>`.
`<definition>`, `<citation>`, `<lexical-unit>` use **`multitext-content`** — `@lang` sits on child `<form>`s.

## 2. Extensibility — the three generic carriers

```
extensible-without-field-content ::= @dateCreated? @dateModified?
                                   & zeroOrMore <annotation> & zeroOrMore <trait>
extensible-content               ::= extensible-without-field & zeroOrMore <field>
```

| Element | Required attrs | Optional attrs | Content | Uniqueness rule |
|---|---|---|---|---|
| `<trait>` | `name`, `value` | — | `zeroOrMore <annotation>` | none |
| `<field>` | **`type`** (0.13; `name` in 0.15) | — | multitext & extensible-without-field | **one `<field>` per `@type` per parent** |
| `<annotation>` | `name` | `value`, `who`, `when` (date/dateTime) | multitext | none |
| `<URLRef>` (`media`, `illustration`) | `href` (anyURI) | — | optional `<label>` (multitext) | — |

## 3. Content models & cardinality (lift-0.13.rng)

```
<lift version="0.13" producer?>  ::= <header>? , zeroOrMore <entry>
<header>   ::= <description>? & <ranges>? & <fields>?          (all interleaved, all optional)

<entry id? guid? order:int? dateDeleted:date?> ::= extensible
     & <lexical-unit>?     multitext
     & <citation>?         multitext
     & zeroOrMore <pronunciation> <variant> <sense> <note> <relation> <etymology>

<sense id? order:int?> ::= extensible
     & <grammatical-info value=…>?   (+ zeroOrMore <trait>)
     & zeroOrMore <gloss lang=…>
     & <definition>?                 multitext
     & zeroOrMore <relation> <note> <example> <reversal> <illustration> <subsense>

<pronunciation>   ::= multitext & extensible & zeroOrMore <media href=…>
<example source?> ::= multitext & extensible & zeroOrMore <translation> <note>
<translation type?>   ::= multitext          one per @type per parent (back|free|literal)
<note type?>          ::= multitext & extensible    one per @type per parent
<relation type=… ref=… order?>  ::= extensible & <usage>?
<illustration>        ::= URLRef
<etymology type=… source=…>     ::= extensible & zeroOrMore <form> <gloss>
<variant ref?>        ::= extensible & multitext & zeroOrMore <pronunciation> <relation>
<reversal type?>      ::= multitext & <main>? & <grammatical-info>?
```

Note `<entry>` is `zeroOrMore <sense>` and every sub-element is optional — the schema is far laxer than any consumer. **Cardinality is not your constraint; consumer expectations are.**

## 4. Ranges (`.lift-ranges`)

`<header><ranges><range id="status" href="file://…/X.lift-ranges"/></ranges></header>` points at a sidecar whose root is `<lift-ranges>`, containing `<range id=…>` / `<range-element id=… guid=…>` with `<label>`, `<abbrev>`, `<description>` (each a multitext). Ranges supply the **controlled vocabulary** that `<trait @value>` and `<grammatical-info @value>` reference (POS, semantic-domain-ddp4, locations, statuses, morph-type…). FLEx behaviour on import: *"any references to range elements in senses and entries will try to find an existing item in the FLEx list. If not found, a new item will be added to the FLEx list."* → **you may emit `<grammatical-info value="Noun">` with no ranges file at all**; FLEx will create the list item and log it.

## 5. Audio — spec vs. de-facto

| | Spec-sanctioned | WeSay/FLEx de-facto |
|---|---|---|
| Shape | `<pronunciation><media href="apple.wav"><label>…</label></media></pronunciation>` | `<form lang="xxx-Zxxx-x-audio"><text>file.wav</text></form>` inside any multitext |
| Where | `<pronunciation>` only | lexical-unit, citation, example, … anywhere a `<form>` goes |
| Cardinality | `zeroOrMore <media>` | **one file only** — one form per `@lang` per parent |
| Source | lift-0.13.rng `pronunciation-content` / `URLRef-content` | Zook §5 *Lexeme Form*: `<form lang="fr-Zxxx-x-audio"><text>…test.wav</text></form>`; *"Audio or video files can be referenced using a special audio writing system. Only one file can be included in the audio writing system… can handle .wav and .mp3 files."* |

`Zxxx` = ISO 15924 "code for unwritten documents"; `-x-audio` is the BCP-47 private-use marker. Path is **a bare filename**, relative to `LinkedFiles\AudioVisual` (FLEx) / the `audio/` folder (LIFT project layout).

**A-Z+T uses the de-facto form, exclusively.** `backend/langtags.py:43` → `audio_code='-Zxxx-x-audio'`; `io_put/lift.py:156-162` `audiolangname()` = `analang + audio_code`; `io_put/export.py` runs on `audiolang='gnd-Zxxx-x-audio'`. It **reads** `<media href>` in exactly one place — `io_put/lift.py:3838` — and that method (`copy_ph_form_and_media_to_lc`, :3836-3843) exists to *convert media into an audio form* under `<citation>`. It never writes a `<media>` element. (`addmediafields`, :1085-1105, is a misnomer — it writes a `<form>`.)
⚠ `CONTEXT.md:20-24`, `docs/adr/0002-…md`, and `tests/test_asr_drafts.py:35` all say `-x-audio`. **The docs are stale; the code is `-Zxxx-x-audio`.** The tests build their own fixture strings and never touch the constant.

## 6. Round-trip survival of unknown `<field>` / `<trait>` / `<annotation>`

- **FLEx: preserved, not dropped.** Zook §8: *"LIFT imports attempt to store any data from the LIFT file that cannot be stored in normal FieldWorks objects so that a LIFT export will return the unused data… by storing LiftResidue fields that will never get deleted via the user interface."* There is also a first-class `<field type="import-residue">` on entry and sense.
- **WeSay: preserved, not editable.** Zook §9: *"For areas it doesn't support, it should not lose any LIFT data, but it will only allow you to edit parts it understands."*
- **`<annotation>` has no FLEx model mapping at all** — grepping all 46 pages, `annotation` appears only as etymology's `field type="preccomment"` and inside the reproduced RNG. So A-Z+T's ASR drafts survive FLEx as opaque residue, never as fields.
- **FLEx `File…Import…LIFT` is additive only**: *"You can add new information or modify some existing fields, but you can't remove fields that are already in the FLEx project."* Deletion needs `dateDeleted` on `<entry>`, or Send/Receive.
- FLEx auto-creates missing **writing systems**, **list items**, and **custom fields** on import (typed correctly only if `<header><fields>` declares them with the `qaa-x-spec` pseudo-writing-system).

## 7. What A-Z+T actually does with LIFT — the answer to the scoping question

**A-Z+T has no LIFT writer.** `read()` (`io_put/lift.py:1170`) → stdlib `ET.parse`; `write()` (`:1240`) → `xmlfns.indent()` then `tree.write(tmp, encoding="UTF-8")` on *the same tree*. No `<lift>` constructor, no `<header>`/`<ranges>`/`<fields>` code anywhere (grep: zero hits). Consequences:

1. **A-Z+T's output LIFT ≡ its input LIFT + a bounded delta.** Everything it doesn't understand — header, ranges, notes, relations, variants, etymologies, reversals, subsenses, spans — passes through byte-equivalent (whitespace re-indented at 4 spaces, `utilities/xmlfns.py:9-26`).
2. **It emits no XML declaration** (`encoding="UTF-8"` suppresses it in CPython — verified empirically). Legal, but a transform should still emit one.
3. It **deletes** empty `<form>`s and empty `<sense>`s (`:4755-4781`), except forms whose lang contains `-Zxxx-x-audio`, `-x-ipa`, `-x-tone`, `_MT`, or that sit inside a `<field>`. Entries with no senses are dropped (`:2984-2990`).

### The bounded delta — everything A-Z+T writes

| Node | Where | Source |
|---|---|---|
| `<entry dateCreated dateModified guid id>` | root | `addentry` :345-350 |
| `<lexical-unit/>` — **created empty on purpose** | entry | :351 + comment :352-353 |
| `<citation><form lang=analang><text>` ← the headword | entry | :359-362 |
| `<sense id=…>`, `<grammatical-info value=ps>` | entry | :364-366 |
| `<definition><form lang=glosslang>`, `<gloss lang=glosslang><text>` | sense | :367-377 |
| `<pronunciation>` + `<field type="tone">` + `<field type="gloss">` + `<trait name="location">` | entry | `addpronunciationfields` :1113-1155 |
| `<field type=…>`: `lc`, `lx`, `tone`, `location`, `SILCAWL`, `cvprofile-user_` | entry/sense | :602, :976-1082, :1731, :3285 |
| `<form lang="{analang}-Zxxx-x-audio\|-x-tone\|-x-ipa\|…_MT">` | citation/lexical-unit/example/field | :1085-1105, langtags.py:41-44 |
| `<annotation name= value=>` on a `<form>` (ASR drafts, revert history) | form | :2155, :2572-2594; ADR 0002 |
| example fields | sense | `addmodexamplefields` :777 |

**Alignment with FLEx is better than expected**: `<pronunciation>` + `field type="tone"` + `trait name="location"` is *exactly* FLEx's own Pronunciation mapping (Zook §5). Only `<field type="gloss">` inside `<pronunciation>` and `type="cvprofile-user_"` are A-Z+T-only (FLEx's is `cv-pattern`). FLEx's full known set: `import-residue, tone, summary, scientific-name, preccomment, note, literal-meaning, languagenotes, exemplar, cv-pattern, comment, bibliography`.

---

## 8. SCOPE for a Dekereke ⇄ LIFT XSLT driven by A-Z+T output

Dekereke side (`/Users/Seth/dekereke-pa-data-source/sample-data/SampleLang_full.xml`): root `<phon_data>` → `<data_form>` × N, children = user-defined column names, empties self-closing.

### IN SCOPE — the whole target vocabulary is ~12 elements

| LIFT | Dekereke column | Notes |
|---|---|---|
| `<lift version="0.13">` | — | must be literal `0.13` |
| `<entry guid id dateCreated dateModified>` | `Reference` → `id` | mint a UUID for `guid`; `id` must be unique in the file |
| `<lexical-unit/>` | — | **emit it empty** — A-Z+T requires the element |
| `<citation><form lang="{analang}">` | `Phonetic` | A-Z+T's headword home, not lexical-unit |
| `<citation><form lang="{analang}-fonipa">` etc. | `Phonemic`, `Orthography`, `Tulisan`, `SpeakerA` | need **distinct lang tags** — one form per `@lang` per parent |
| `<citation><form lang="{analang}-Zxxx-x-audio"><text>` | `SoundFile` (bare `.wav`) | folder from the sibling `-DkUserSettings.xml` `<sound_file_path>`; do NOT emit `<media href>` |
| `<sense id=…>` | — | ≥1 required or A-Z+T drops the entry |
| `<gloss lang="en">`, `<gloss lang="id">` | `Gloss`, `IndonesianGloss` | `@lang` on `<gloss>` itself |
| `<definition><form lang=…>` | same | `@lang` on `<form>` |
| `<grammatical-info value=…>` | `Category` | FLEx auto-creates the list item |
| `<pronunciation><form lang="{analang}">` + `<field type="tone"><form lang="{glosslang}">` + `<trait name="location" value=…>` | `Pitch`, `Surface_Melody`, `Nada`; frame name → location | FLEx-native round trip |
| `<field type="cv-pattern">` in `<pronunciation>` | `SyllableProfile` | prefer FLEx's `cv-pattern` over A-Z+T's `cvprofile-user_` |
| `<example><form lang="{analang}">` + `<translation>` | frame columns `goodX`, `whiteX`, `Xbad`, `Xneg`, `pigX`, `Xpig`, `Xwater`, `CMPLalt`, `INCMP`, `IMP-re`, `SVC`, `SEQ` | each `_Pitch` twin → the example's own tone field/form |
| `<note>` | `Notes` | pass-through; A-Z+T has zero `note` code so it survives untouched |

### OUT OF SCOPE

- **`<header>` / `<ranges>` / `<fields>` / a `.lift-ranges` sidecar** — A-Z+T never reads or writes them; FLEx creates missing list items on import. Emit none. (Emit `<header><fields>` only if you later need typed FLEx custom fields.)
- **`<media href>`** — spec-correct but A-Z+T converts it away. Use the audio form.
- **`<relation>`, `<variant>`, `<etymology>`, `<reversal>`, `<subsense>`, `<illustration>`, `<span>`, `<usage>`, `<main>`** — no Dekereke source and no A-Z+T code path (`grep` counts in `io_put/lift.py`: relation 0, variant 0, etymology 0, reversal 0, span 0). `<illustration>` is read-only, for SILCAWL images.
- **`<annotation>`** — A-Z+T's private ASR/revert namespace. A converter must never mint one; it is not an import channel.
- **`<qvp_acoustic_data_>`** — ignore (per Dekereke README).
- **Dekereke columns with no model home**: `Type`, `VerbClass`, `Inflection_Class`, `Orth.practice`. Either drop, or park in `<field type="…">` accepting that they become LiftResidue in FLEx and are invisible in A-Z+T.
- **LIFT 0.15 features and the repo's `lift.rng`** — `field/@name`, etc. Wrong schema for every consumer.
- **Deletion semantics** — FLEx import is additive; only `dateDeleted` on `<entry>` deletes. Out of scope for an importer.

### Hard constraints the XSLT must respect

1. `version="0.13"` literal, `<?xml version="1.0" encoding="UTF-8"?>`, UTF-8/NFC output.
2. **One `<form>` per `@lang` per parent** — Phonetic/Phonemic/Orthography/Tulisan/SpeakerA must get distinct tags or distinct parents.
3. **One `<field>` per `@type` per parent**; one `<note>` per `@type`; one `<translation>` per `@type`.
4. `<gloss>` carries `@lang`; `<definition>` carries `<form lang=…>`. Do not swap them.
5. **Never emit an empty `<form>` or an empty `<sense>`** — Dekereke's self-closing empties must produce *no element*, not an empty one (A-Z+T strips them anyway; a record with empty `Phonetic` must be skipped entirely).
6. Emit `<lexical-unit/>` even though it stays empty.
7. Audio tag = `{analang}-Zxxx-x-audio`. **Do not build it by string concatenation off an analang that carries `-x-…`** — see the open question below.
8. On the export side, mirror the reader: hand raw bytes to the parser and let BOM/declaration resolve the encoding (UTF-16LE+BOM, UTF-8+BOM, bare UTF-8 all live).

### Implementation seam

`lxml` is an unconditional dependency (`requirements.txt` line 21) and `io_put/xlp.py:90-171` already chains four `lxml.etree.XSLT` transforms over stylesheets in `xlptransforms/`, resolved by `file.gettransformsdir()`, with `transform[n].error_log` drained to the app log. Copy that shape into a `dekereke.py` beside `io_put/lift.py`, with stylesheets in a new `dekerektransforms/` (or alongside). Note `io_put/lift.py` deliberately forces `lxml=False` (`:7-16`) and uses stdlib `xml.etree` — keep the XSLT stage separate from the LIFT object model rather than switching `lift.py` to lxml.

## Open questions
- `audiolangname()` (io_put/lift.py:156-162) builds the audio tag by bare concatenation: `analang + '-Zxxx-x-audio'`. For Fayu the analang may carry a private-use dialect subtag (`iau-x-tmu`?), which yields `iau-x-tmu-Zxxx-x-audio` — malformed BCP-47 (script subtag after a private-use section; two `x-` singletons). What is the actual analang string in Seth's Fayu project, and does `self.audiolang` get set from settings (bypassing the concat) or derived? Same concat pattern affects `-x-tone` and `-x-ipa`. This must be settled before the transform emits any audio form.
- CONTEXT.md:20-24, docs/adr/0002-asr-drafts-as-audio-form-annotations.md, and tests/test_asr_drafts.py:35 all say `-x-audio` while backend/langtags.py:43 says `-Zxxx-x-audio`. Is this a documentation lag, or was there a real migration (git log -S on that line shows only a merge commit, b1249d1)? Do Kent's live WeSay/FLEx files contain `-x-audio` forms that A-Z+T can no longer see? A Dekereke importer picking the wrong one writes audio A-Z+T will not find.
- Which of the four headword renderings (Phonetic, Phonemic, Orthography, Tulisan, SpeakerA) should be A-Z+T's `analang` form, and which writing-system tags should the rest get? LIFT forbids two `<form>`s with the same `@lang` in one parent, so this is a forced decision, not a preference. `-fonipa` (IPA) and `-Latn`/plain are the obvious candidates but need Kent's/Seth's call and matching `.ldml` files if FLEx is ever a consumer.
- A-Z+T writes `<field type="gloss">` inside `<pronunciation>` (io_put/lift.py:1134, :1152), which is not in FLEx's known field-type set. Confirm empirically that FLEx round-trips it as LiftResidue rather than erroring — the LiftResidue guarantee is documented but untested for this specific case.
- Should the transform emit FLEx's `<field type="cv-pattern">` for SyllableProfile (native to FLEx, invisible to A-Z+T) or A-Z+T's `type='cvprofile-user_'` (native to A-Z+T, residue in FLEx)? Both, in different parents, is legal (one field per type per parent) — but is duplicating the datum acceptable to Kent?
- Not established from public sources: whether WeSay's actual implementation (libpalaso `SIL.Lift`) preserves unknown `<annotation>` children of `<form>` specifically, as opposed to unknown `<field>`/`<trait>` on extensible parents. Zook's blanket statement ("it should not lose any LIFT data") is the only citation found; the libpalaso source was not read. If A-Z+T's ASR drafts must survive a WeSay Send/Receive, this needs verifying against SIL.Lift's LiftParser/LiftWriter directly.
- Dekereke `Reference` values (e.g. `0003`) are database-local. Should they become the LIFT `@id`, a `<field type="…">`, or both? FLEx only keeps `id` in LiftResidue when a `guid` is present (Zook §8: "They will only be saved in LiftResidue"), so re-import round trips will not preserve Reference as data unless it is also a field.