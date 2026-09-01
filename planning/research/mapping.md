# Research: mapping

_Auto-captured from the 2026-09-02 research workflow. Verified findings only —
see `verify-corrections.md` for what the adversarial pass overturned._

## Summary

Both Dekereke samples' column inventories are enumerated and classified (41 text columns + 1 nested block in the full DB; 15 in the minimal DB; only 6 columns shared — confirming "user-defined per database"). A-Z+T's LIFT vocabulary is fully pinned to file:line: entries carry the headword at `entry/citation/form[@lang=analang]/text` (lift.py:357-361, with `lexical-unit` created but EMPTY at :350), glosses duplicated into both `sense/definition/form` and `sense/gloss` (:366-377), and everything A-Z+T itself computes lives in `<field>` elements distinguished by private-use language tags (`-Zxxx-x-audio`, `-x-tone`, `-x-cvprofile`, `-x-ipa`, `-x-py`, `_MT`; langtags.py:41-44). The single hardest structural constraint on any importer is lift.py:1372-1391: A-Z+T discovers its analang ONLY from `entry/citation/form`, `entry/lexical-unit/form`, `entry/pronunciation/form`, and only from tags passing `langtags.tag_is_valid` — so Phonetic MUST land in one of those three or the project won't open. The best structural correspondence in the whole mapping is that Dekereke's frame columns (goodX, Xbad, …) and paradigm columns (INCMP, SVC, …) with their `_Pitch` twins map almost exactly onto A-Z+T's `sense/example` + `example/field[@type='location']` + `example/field[@type='tone']` triple — Dekereke's flat "one column per frame" and A-Z+T's "one example per frame" are the same idea in two shapes. Import is close to lossless if two things are stashed (the column inventory + the Reference); export to Dekereke is heavily lossy and should never be treated as the master copy.

## Findings

- **[high]** A-Z+T discovers its analang ONLY from citation/lexical-unit/pronunciation form langs, and only from BCP-47-valid tags. An importer that writes the phonetic form anywhere else (e.g. only into a <field>) produces a LIFT file A-Z+T cannot open.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1372-1391 `collect_and_sort_plausible_lang_codes`: `langs=[i.get('lang') for i in self.nodes.findall('entry/citation/form')+self.nodes.findall('entry/lexical-unit/form')+self.nodes.findall('entry/pronunciation/form')]`, then `self.analangs=[i for i in l_ordered if langtags.tag_is_valid(i) and self.language_codes['machine'] not in i]`; `get_langs` (:1364-1371) raises ValueError from `find_plausible_analang` when none is found.

- **[high]** A-Z+T's own `addentry` puts the headword in `citation`, NOT in `lexical-unit` — it creates `<lexical-unit/>` empty as a placeholder. So a Dekereke importer should mirror that: Phonetic -> citation form.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:350-352 `lexicalunit=et.SubElement(entry, 'lexical-unit', attrib={})` followed by the comment "Just adding citation, not lexeme forms, with this function, though we need the lexeme field (above) to be there"; :357-361 builds `citation/form[@lang=analang]/text`. Reinforced by templates.py:96 calling `self.db.strip_lxlc_forms()` and lift.py:1359-1363 removing all `entry/lexical-unit` and `entry/citation` forms from the CAWL template.

- **[high]** Every A-Z+T-computed value is stored in a `<field>` whose FORM is tagged with a private-use language subtag, not in a distinct element. The tags are `{analang}-Zxxx-x-audio`, `{analang}-x-tone`, `{analang}-x-ipa`, `{analang}-x-cvprofile`, `{analang}-x-py`, each optionally suffixed `_MT` for machine-generated values.
  - _evidence:_ /Users/Seth/GIT/azt/backend/langtags.py:41-44 `tone_code='-x-tone'`, `phonetic_code='-x-ipa'`, `audio_code='-Zxxx-x-audio'`, `machine_transcription_code='_MT'`; lift.py:4654 `def pylang(analang): return analang+'-x-py'`; lift.py:4656-4663 `profilelang` -> `analang+'-x-cvprofile'` (+`_MT`); lift.py:147-170 `tonelangname`/`audiolangname`/`phoneticlangname`.

- **[high]** The `_MT` suffix is semantically load-bearing: the plain form means USER-CONFIRMED, the `_MT` form means MACHINE-ANALYZED. Dekereke's SyllableProfile / Pitch / Nada / Surface_Melody are Dekereke-side annotations, not A-Z+T sort results, so importing them into the plain form would falsely mark words as confirmed — a bug A-Z+T already fixed once.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:3296-3303 docstring: "machine=False -> the plain …-x-cvprofile form (the user-confirmed profile / sorting result); machine=True -> the …-x-cvprofile_MT form (the raw machine analysis) … NOT by whichever form happens to exist — so reading the plain value returns None when only the _MT form is present (the bug that made unprofiled words look profiled: no affirm trigger, affirm's !=m guard skipping them, segmental sorts reading raw machine as confirmed)."

- **[high]** Dekereke's per-frame and per-paradigm-slot columns with their `_Pitch` twins are structurally isomorphic to A-Z+T's `sense/example` + `example/field[@type='location']` (frame name) + `example/field[@type='tone']` (surface tone in that frame). This is the single strongest correspondence in the mapping and it is bidirectional.
  - _evidence:_ Dekereke side: SampleLang_full.xml columns goodX/whiteX/Xbad/Xneg/pigX/Xpig/Xwater each with a `<name>_Pitch` twin (goodX_Pitch, Xbad_Pitch, …), and paradigm slots CMPLalt/INCMP/IMP-re/SVC/SEQ each with a `_Pitch` twin. A-Z+T side: /Users/Seth/GIT/azt/io_put/lift.py:3238-3241 `getexamples` keys examples by `example/field[@type="location"]/form/text`; :3218-3232 `newexample(loc,frame,…)` sets `textvaluebylang(analang)`, `tonevalue()`, `locationvalue(loc)`, `translationvalue()`; :5006-5015 the explicit XPath `sense/example/field[@type='location']/form[@lang='{glosslang}'][text='{location}']/../../field[@type='{fieldtype}']/…`.

- **[high]** Both systems store BARE audio filenames, so the filename maps one-to-one — but neither stores the folder in the file being mapped, and the two folder-resolution rules are incompatible. Dekereke keeps it in a sibling settings file; A-Z+T hard-codes `<lift_home>/audio`. The folder value itself is unmappable and the .wav files must be physically copied.
  - _evidence:_ Dekereke: SampleLang_full-DkUserSettings.xml `<sound_file_path>C:\SampleLang\audio</sound_file_path>`; /Users/Seth/dekereke-pa-data-source/src/DekerekeToPa/DekerekeFile.cs `TryReadSoundFilePath` reads `<basename>-DkUserSettings.xml`. A-Z+T: /Users/Seth/GIT/azt/utilities/file.py:139-143 `def getaudiodir(dirname): dir=pathlib.Path.joinpath(dirname,'audio'); if not os.path.exists(dir): os.mkdir(dir); return dir`, called from lift.py:171-172 `self.audiodir=file.getaudiodir(self.lift_home)`; lift.py:2881-2888 `hassoundfile` joins audiodir + the bare form text.

- **[high]** The C# auto-mapper's heuristic is exact case-insensitive equality against an ordered synonym list — NOT substring, prefix, or regex matching. Order matters twice (fields claim columns in list order; within a field the earlier synonym wins), each column is claimed at most once, and unmatched columns are expected and normal.
  - _evidence:_ /Users/Seth/dekereke-pa-data-source/src/DekerekeToPa/AutoMapper.cs: `match = available.FirstOrDefault(c => !claimed.Contains(c) && string.Equals(c, synonym, StringComparison.OrdinalIgnoreCase));` plus the class comment "For each PA field, in order, the first not-yet-claimed column matching a synonym (case-insensitive) wins; each column is claimed at most once. Unmatched columns stay unmapped - that is normal". Pinned by AutoMapperTests.cs:80-92 (`Map_OrthographyBeatsTulisan_WhenBothPresent`, `Map_PitchBeatsNada_AndNadaStaysUnclaimed`).

- **[high]** The C# heuristics cover only 10 roles and deliberately leave frames, paradigm slots and `_Pitch` twins unmapped — because PA has no home for them. A-Z+T DOES have a home for them (examples), so the Python port must ADD rules the C# code does not contain.
  - _evidence:_ AutoMapper.cs `Synonyms` array has exactly 10 entries (Phonetic, Reference, Tone, Phonemic, Gloss, GlossSecondary, PartOfSpeech, Orthographic, AudioFile, Note); PaFieldNames.cs `All` lists the same 10. AutoMapperTests.cs:59-60 asserts `Does.Not.Contain("goodX")` and `Does.Not.Contain("Xbad")` — the frames staying unmapped is a TESTED behaviour, not an oversight.

- **[medium]** A-Z+T tolerates arbitrary entry-level and sense-level `<field type="...">` names generically, so stashing unmapped Dekereke columns as LIFT fields will not crash it — provided each such field carries exactly one form-lang, or carries the analang among its forms.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1473-1485 `getfieldnames` builds `self.fieldnames` from whatever `i.fields` keys exist on entries, with no whitelist; :1583-1588 `fieldopts` interpolates those names straight into XPaths `field[@type="{}"]`; :2686-2707 `getlang` falls through to `elif len(possibles)==1: return possibles[0]` and `elif analang in possibles: return analang`, raising only when neither holds. Dekereke column names containing `-` and `.` (IMP-re, Orth.practice) are legal inside an XPath attribute-value predicate.

- **[high]** A-Z+T's sort/verification data has no representable equivalent in Dekereke and must never be round-tripped through it. It is a str()-ified Python list of `check=group` codes living in a `-x-py` form on a field whose TYPE encodes the profile.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:3610-3616 `verificationkey` returns `f'{profile} {ftype} verification'` / `f'{ftype} primitive verification'` / `f'{ftype} verification'`; :3617-3650 `verificationtextvalue` stores `str(value)` of a Python list and reads it back with `xmlfns.stringtoobject`; :2695-2696 the form lang is `pylang(analang)` = `{analang}-x-py`; :3664-3668 codes look like `'#C=C' / 'C#=V' / 'syls=2'`.

- **[high]** A record with an empty Phonetic must be skipped on import (it cannot become a LIFT entry with a headword), and the full sample contains exactly such a record, flagged Category=DUPLICATE. This is a silent row-count change the importer must report.
  - _evidence:_ SampleLang_full.xml `<Reference>0012</Reference><Gloss>descend.INCMP</Gloss><Category>DUPLICATE</Category>…<Phonetic/>` — 9 of 10 records have Phonetic filled. Existing precedent: /Users/Seth/dekereke-pa-data-source/src/DekerekeToPa/SfmWriter.cs increments `result.RecordsSkippedNoPhonetic` and `continue`s when `string.IsNullOrEmpty(phonetic)`. README.md in sample-data calls it out: "a record with empty `Phonetic` (must be skipped on conversion)".

- **[high]** The two sample databases share only 6 column names out of 41 and 15 respectively, so no fixed XSLT template matching on element names can work — the stylesheet must be parameterised by a runtime-determined column map (or generated per database).
  - _evidence:_ Full DB columns (first-seen order, 41 text + 1 nested): Reference, Gloss, IndonesianGloss, Category, Type, SyllableProfile, Phonetic, Pitch, CMPLalt, CMPLalt_Pitch, INCMP, INCMP_Pitch, IMP-re, IMP-re_Pitch, SVC, SVC_Pitch, SEQ, SEQ_Pitch, Notes, SoundFile, goodX, whiteX, Xbad, Xneg, pigX, Xpig, Xwater, Xwater_Pitch, Xneg_Pitch, Xbad_Pitch, goodX_Pitch, whiteX_Pitch, Phonemic, Orth.practice, VerbClass, Orthography, Surface_Melody, SpeakerA, Tulisan, Nada, Inflection_Class, qvp_acoustic_data_. Minimal DB (15): Reference, Category, SoundFile, IndonesianGloss, Phonetic, Tulisan, Speaker2, kosong, Xstraight, Xbig, Xbroken, Xnearby, Xstrong, Xlike, Catatan. Intersection = {Reference, Category, SoundFile, IndonesianGloss, Phonetic, Tulisan}. HANDOFF.md trap 5: "The two real databases this was built against share only ~6 of ~70 and ~16 columns. Never hard-code a mapping."

- **[high]** Dekereke's user-settings file declares per-column sound-file SUFFIX mappings, meaning one record can own several recordings derived from the single SoundFile value. A-Z+T's model is one audio filename per form-parent, so the derived names must be materialised explicitly or lost.
  - _evidence:_ SampleLang_full-DkUserSettings.xml: `<column_to_sound_file_suffix_mappings><column_to_sound_file_suffix_mapping>Phonetic\t-phon</…><column_to_sound_file_suffix_mapping>Speaker2\t-sp2</…></…>`. The C# reader reads only `<sound_file_path>` from that file (DekerekeFile.cs `TryReadSoundFilePath`) — the suffix mappings are currently DROPPED even in the PA path.

- **[high]** A-Z+T offers exactly one inflection-class slot per sense, but the full Dekereke sample carries three independent subclass axes (Type=tr/intr, VerbClass=I/II, Inflection_Class=e-stem/a-stem). Two of the three cannot occupy the native trait.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:3317-3325 `pssubclassvalue` finds `trait[@name="{}-infl-class".format(self.psvalue())]` — one trait, named from the ps value; lift.py:4003-4013 `LiftURL.pssubclass` builds `<trait name='{ps}-infl-class' value='{pssubclass}'>`. Dekereke side: SampleLang_full.xml record 0019 carries `<Type>tr</Type>`, `<VerbClass>I</VerbClass>`, `<Inflection_Class>e-stem</Inflection_Class>` simultaneously.

- **[high]** The `<qvp_acoustic_data_>` nested block is already dropped by the reference C# reader by a general rule (any element with children is not a column), and has no LIFT home at all. It is the clearest single item of import loss.
  - _evidence:_ /Users/Seth/dekereke-pa-data-source/src/DekerekeToPa/DekerekeFile.cs: `foreach (var el in form.Elements()) { if (el.HasElements) continue; // qvp_acoustic_data_ and any other nested block`. Content in SampleLang_full.xml: `<qvp_acoustic_data_set><qvp_column>Phonetic</qvp_column><qvp_acoustic_data_string>V1T:0.212,V1F1:412,V1F2:1930</qvp_acoustic_data_string></qvp_acoustic_data_set>`.

- **[high]** The lang tag A-Z+T uses for non-linguistic field forms (SILCAWL number, tone-frame location name) is the FIRST glosslang, not the analang. A Dekereke Reference field modelled on SILCAWL must do the same.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1471 `self.annotationlang=self.glosslangs[0]`; :2698-2699 `elif self.ftype in ['location', 'SILCAWL']: return self.annotationlang`; :3055-3056 FieldParent inherits `annotationlang` from its parent; :3846 `self.annotationlang=kwargs.pop('annotationlang','en')` as the default.

- **[medium]** An XSLT-only transform cannot complete the Dekereke->LIFT job: A-Z+T entries require freshly generated 8-4-4-4-12 hex GUIDs for `entry/@guid` and `sense/@id`, and `entry/@id` is built as `<form>_<guid>`. lxml is XSLT 1.0, which has generate-id() but not a UUID generator.
  - _evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:317-332 `makenewguid` builds `rxi(8)+'-'+rxi(4)+'-'+rxi(4)+'-'+rxi(4)+'-'+rxi(12)` from `randint(0,15)` hex digits and loops until unique against `self.guids`+`self.senseids`; :345-349 `attrib={'dateCreated':now,'dateModified':now,'guid':guid,'id':(kwargs['form'][analang]+'_'+str(guid))}`. The in-repo XSLT precedent (io_put/xlp.py:115-140, `lxml.etree.XSLT`) has no extension functions registered.


## Artifact

> Scope note (per Seth's framing): the LIFT column of every row below is what **A-Z+T itself writes or reads**, evidenced at file:line in `/Users/Seth/GIT/azt/io_put/lift.py`. It is not general LIFT and not FLEx's full export surface.

---

# 1. Column inventories, classified

## 1a. `SampleLang_full.xml` — 41 text columns + 1 nested block, 10 records (UTF-16LE+BOM)

First-seen element order (= Dekereke's own column order).

| # | Column | Role | Sample values |
|---|---|---|---|
| 1 | `Reference` | **identifier** | `0003`, `0007` (zero-padded, 10/10) |
| 2 | `Gloss` | **gloss — English** | `tree`, `fish`, `descend.INCMP` |
| 3 | `IndonesianGloss` | **gloss — Indonesian** | `pohon`, `ikan`, `turun` |
| 4 | `Category` | **category/POS** | `Noun`, `Verb`, `Adj`, `DUPLICATE` |
| 5 | `Type` | **POS subclass (transitivity)** | `tr`, `intr` (2/10) |
| 6 | `SyllableProfile` | **CV/syllable profile** | `CVV`, `CVCV`, `VVCV` |
| 7 | `Phonetic` | **phonetic form** | `bɔi`, `seɯa`, `ɸede` (9/10) |
| 8 | `Pitch` | **pitch/tone annotation** (of `Phonetic`) | `[K k]`, `[3 K k]`, `[4]` |
| 9 | `CMPLalt` | **verb-paradigm slot** | `ɸedi` |
| 10 | `CMPLalt_Pitch` | pitch annotation of #9 | `[K k]` |
| 11 | `INCMP` | **verb-paradigm slot** | `ɸeda`, `adi` |
| 12 | `INCMP_Pitch` | pitch annotation of #11 | `[3 4]`, `[3]` |
| 13 | `IMP-re` | **verb-paradigm slot** (name has `-`) | `ɸedeɲa` |
| 14 | `IMP-re_Pitch` | pitch annotation of #13 | `[]` |
| 15 | `SVC` | **verb-paradigm slot** | `ɸede ba` |
| 16 | `SVC_Pitch` | pitch annotation of #15 | `[]` |
| 17 | `SEQ` | **verb-paradigm slot** | `ɸede te`, `ada te` |
| 18 | `SEQ_Pitch` | pitch annotation of #17 | `[]` |
| 19 | `Notes` | **note** | `second elicitation session; cf. 0021` |
| 20 | `SoundFile` | **sound file** (bare name) | `0003_tree.wav` |
| 21 | `goodX` | **elicitation frame** (word 2nd) | `kaba bɔi` |
| 22 | `whiteX` | **elicitation frame** (word 2nd) | `kɔdɔ bɔi` |
| 23 | `Xbad` | **elicitation frame** (word 1st) | `bɔi ɸai` |
| 24 | `Xneg` | **elicitation frame** | `bɔi dʒa` |
| 25 | `pigX` | **elicitation frame** | `dị bɔi` |
| 26 | `Xpig` | **elicitation frame** | `bɔi dị` |
| 27 | `Xwater` | **elicitation frame** | `bɔi du` |
| 28–32 | `Xwater_Pitch`, `Xneg_Pitch`, `Xbad_Pitch`, `goodX_Pitch`, `whiteX_Pitch` | pitch annotations of 5 of the 7 frames | `[]`, `[3 5 4]` |
| 33 | `Phonemic` | **phonemic form** (syllabified with `.`) | `bɔi`, `se.wa`, `ku.di` |
| 34 | `Orth.practice` | orthographic (practice); name has `.` | *(0/10 — empty in every record)* |
| 35 | `VerbClass` | **POS subclass** | `I`, `II` |
| 36 | `Orthography` | **orthographic form** | `boi`, `sewa`, `fede` |
| 37 | `Surface_Melody` | **tone annotation** (word melody) | `H`, `LH`, `HL`, `L` |
| 38 | `SpeakerA` | **alternate-speaker form** | `bɔi`, `sewa`, `kudi` |
| 39 | `Tulisan` | **orthographic form** (Indonesian label) | `boi`, `sewa` — identical to #36 here |
| 40 | `Nada` | **tone annotation** (Indonesian label) | `TA`, `BA` |
| 41 | `Inflection_Class` | **POS subclass** | `e-stem`, `a-stem` |
| 42 | `qvp_acoustic_data_` | **other — nested block, ignore** | `<qvp_column>Phonetic</…><qvp_acoustic_data_string>V1T:0.212,V1F1:412,V1F2:1930</…>` |

Note the **asymmetry**: 7 frame columns but only 5 `_Pitch` twins (`pigX`, `Xpig` have none). A pairing rule must tolerate missing twins.

## 1b. `SampleLang_minimal.xml` — 15 columns, 6 records (plain UTF-8, no BOM)

| # | Column | Role | Sample values |
|---|---|---|---|
| 1 | `Reference` | **identifier** | `0012`, `0015` |
| 2 | `Category` | **category/POS** | `Verb`, `Noun`, `Adj` |
| 3 | `SoundFile` | **sound file** | `0012_turun.wav` |
| 4 | `IndonesianGloss` | **gloss — Indonesian** | `turun`, `rawa`, `batu` |
| 5 | `Phonetic` | **phonetic form** | `oudo`, `tei`, `haɭe` |
| 6 | `Tulisan` | **orthographic form** | `oudo`, `hale` |
| 7 | `Speaker2` | **alternate-speaker form** | `siga` vs `sika` for Phonetic |
| 8 | `kosong` | **other — record flag** ("empty") | `x` on the one empty record |
| 9–14 | `Xstraight`, `Xbig`, `Xbroken`, `Xnearby`, `Xstrong`, `Xlike` | **elicitation frames** | `tei dobe`, `tei kɔi`, `kɔi mɛ` |
| 15 | `Catatan` | **note** (Indonesian) | `periksa dengan penutur lain` |

**Intersection of the two inventories = 6 columns**: `Reference`, `Category`, `SoundFile`, `IndonesianGloss`, `Phonetic`, `Tulisan`. Nothing else is shared. No hard-coded element-name matching can work.

---

# 2. The mapping table

Legend for **direction**: `D→A` = Dekereke to A-Z+T LIFT; `A→D` = LIFT to Dekereke; `↔` = both, with the loss noted. `analang` = the object language's BCP-47 tag; `G1` = `glosslangs[0]` (lift.py:1471).

| # | Dekereke column role | A-Z+T LIFT location (XPath, relative to `lift/`) | Dir | Notes / loss |
|---|---|---|---|---|
| 1 | **Reference** (`Reference`, `Ref`, `No`, `Nomor`) | *No native home.* **Proposed:** `entry/field[@type='Dekereke-Reference']/form[@lang='{G1}']/text`, declared in `lift/header/fields/field[@tag='Dekereke-Reference']` | ↔ | Modelled exactly on A-Z+T's own SILCAWL field (lift.py:4088-4099, :3387), which uses `glosslangs[0]` as the form lang (:1471, :2698). Without this the row identity is lost and a re-import duplicates every entry. `entry/@id` also embeds it indirectly only via the form text (:349). |
| 2 | **Phonetic** (`Phonetic`, `Fonetik`, `IPA`) | `entry/citation/form[@lang='{analang}']/text` | ↔ | **Mandatory target.** A-Z+T's own `addentry` writes the headword here, not to `lexical-unit` (lift.py:350-361). `collect_and_sort_plausible_lang_codes` (:1372-1391) only scans `citation`/`lexical-unit`/`pronunciation` forms for the analang — put it anywhere else and the project won't open. A record with empty Phonetic **must be skipped** (SampleLang_full `0012`). |
| 2b | Phonetic — alternative | `entry/pronunciation/form[@lang='{analang}']/text` (+ `entry/pronunciation/trait[@name='location'][@value='…']`) | ↔ | Also scanned for analang. A-Z+T builds this as `pronunciation/trait[@name='location']/…/form[@lang=analang]` (lift.py:3983-3990; explicit XPath at :4971-4980). Use only if a project wants citation reserved for orthography. |
| 3 | **Phonemic** (`Phonemic`, `Fonemik`) | `entry/citation/form[@lang='{analang}-x-ipa']/text` **or** `entry/field[@type='Dk_Phonemic']/form[@lang='{analang}']/text` | ↔ | `-x-ipa` is A-Z+T's phonetic-transcription tag (langtags.py:43, lift.py:162-170). Semantics are inverted relative to Dekereke (A-Z+T's `-x-ipa` = *phonetic*), so if `Phonetic` already holds IPA, put `Phonemic` in a `Dk_` field instead. **Loss:** the syllable dots in `se.wa`, `ku.di`, `ɸe.de` are Dekereke's syllabification and have no separate A-Z+T slot — they survive only as literal `.` in the text. |
| 4 | **Orthographic** (`Orthography`, `Tulisan`, `Ejaan`) | `entry/lexical-unit/form[@lang='{analang}']/text` | ↔ | The empty `<lexical-unit/>` A-Z+T creates (lift.py:350) is the natural home. Also scanned for analang (:1374-1376). **Loss:** the full sample has BOTH `Orthography` and `Tulisan` (identical values); only one can occupy this slot — the C# heuristic claims `Orthography` and leaves `Tulisan` unmapped (AutoMapperTests.cs:80-84). The second must go to `Dk_Tulisan` or a private-use tag. |
| 5 | **Gloss — English** (`Gloss`, `Arti`, `EnglishGloss`) | `entry/sense/gloss[@lang='en']/text` **and** `entry/sense/definition/form[@lang='en']/text` | ↔ | A-Z+T's `addentry` writes the SAME text into both (lift.py:366-377) — mirror that on import. `glosslang` tag comes from the project, not from the column: `Gloss`→`en`, `IndonesianGloss`→`id`. **Loss on export:** `sense.glosses[lang]` is a LIST (lift.py:3140-3149); multiples must be joined `', '` into the single column. |
| 6 | **Gloss — Indonesian** (`IndonesianGloss`, `Gloss2`, `ArtiIndonesia`, `NationalGloss`) | `entry/sense/gloss[@lang='id']/text` **and** `entry/sense/definition/form[@lang='id']/text` | ↔ | Same as #5. `id` must be a project glosslang or A-Z+T won't display it. |
| 7 | **Category/POS** (`Category`, `POS`, `PartOfSpeech`, `Kategori`, `KelasKata`) | `entry/sense/grammatical-info/@value` | ↔ | Direct (lift.py:363-365). Values are free strings on both sides — no range validation in A-Z+T. **Import filter:** sentinel values (`DUPLICATE` in the full sample, and the `kosong`=`x` flag column in the minimal one) mark rows to drop, not POS values. |
| 8 | **POS subclass** (`Type`, `VerbClass`, `Inflection_Class`) | `entry/sense/trait[@name='{ps}-infl-class'][@value='…']` | D→A (one only) | A-Z+T has exactly ONE such trait per sense, named from the ps value (lift.py:3317-3325, :4003-4013). Sample record `0019` carries all three axes at once → **two of three must become `Dk_` fields.** Export can only rebuild the one that round-tripped. |
| 9 | **Sound file** (`SoundFile`, `Audio`, `Sound`, `Rekaman`) | `entry/citation/form[@lang='{analang}-Zxxx-x-audio']/text` (bare filename) | ↔ | Both sides store a **bare name** — filename maps 1:1, no path munging (unlike the PA path, which prefixes: `SfmWriter.ResolveAudioPath`). **The folder problem:** Dekereke's folder lives in `<basename>-DkUserSettings.xml/<sound_file_path>` (`C:\SampleLang\audio`); A-Z+T hard-codes `<lift_home>/audio` (utilities/file.py:139-143, lift.py:171-172) and cannot be told otherwise from inside the LIFT. **The importer must copy or symlink the .wav files** into `<lift_home>/audio`, and stash the original `sound_file_path` for export. |
| 9b | Per-column audio suffixes | *(none)* | — | `<column_to_sound_file_suffix_mapping>Phonetic⇥-phon` / `Speaker2⇥-sp2` implies several recordings per row derived from the one `SoundFile` value. A-Z+T holds one filename per form-parent. Materialise `0012_turun-sp2.wav` onto the `Speaker2` field's audio form, or lose the extra takes. |
| 10 | **Pitch/tone of the citation form** (`Pitch`, `Tone`, `Nada`, `Surface_Melody`) | `entry/sense/field[@type='tone']/form[@lang='{analang}-x-tone_MT']/text` | ↔ | This is the **UF-tone** field (lift.py:3310-3315). **Use the `_MT` form, not the plain one** — the plain form means *user-confirmed by ear*, `_MT` means *machine/imported* (lift.py:3296-3303 documents the exact bug that conflating them caused). **Loss:** the full DB has THREE tone columns (`Pitch` `[K k]`, `Surface_Melody` `H/LH`, `Nada` `TA/BA`) in different notations; A-Z+T has one human + one machine form per lang tag. Two of three go to `Dk_` fields. |
| 11 | **CV/syllable profile** (`SyllableProfile`) | `entry/sense/field[@type='cvprofile_lc']/form[@lang='{analang}-x-cvprofile_MT']/text` | ↔ | `cvprofilevalue(ftype='lc')` → field type `cvprofile_lc` (lift.py:3295-3305); form lang from `profilelang()` (:4656-4663). Again **`_MT` only** on import. `CVV`/`CVCV` notation already matches A-Z+T's. |
| 12 | **Elicitation-frame columns** (`goodX`, `whiteX`, `Xbad`, `Xneg`, `pigX`, `Xpig`, `Xwater`; `Xstraight`, `Xbig`, …) | `entry/sense/example/field[@type='location']/form[@lang='{G1}']/text` = **the column name**, sibling `entry/sense/example/form[@lang='{analang}']/text` = **the cell value** | ↔ | **The best fit in the whole mapping.** A-Z+T keys examples by that location string (lift.py:3238-3241) and A-Z+T's own `newexample(loc, frame, …)` writes exactly this triple (:3218-3232). Explicit XPath at :5006-5015. One Dekereke column ⇒ one example per record that has a value; empty cells simply produce no example, which is what A-Z+T expects. **Export is clean:** location string → column name, so the column set is rebuildable from the LIFT alone. |
| 12b | Frame `_Pitch` twins (`goodX_Pitch`, `Xbad_Pitch`, …) | `entry/sense/example/field[@type='tone']/form[@lang='{analang}-x-tone_MT']/text` on the SAME example | ↔ | The surface-tone-per-frame slot (lift.py:3063-3068 `Example.tonevalue`). Pairing rule: strip `_Pitch`; if the remainder is a known column, it's that column's twin. Tolerate missing twins (`pigX`, `Xpig` have none) and empty `[]` values. |
| 12c | *Frame translation* | `entry/sense/example/translation[@type='Frame translation']/form[@lang='{G1}']/text` | A→D only | A-Z+T writes a per-frame gloss (lift.py:4021-4026, :3229-3231). Dekereke frame columns have **no translation slot** — dropped on export. |
| 13 | **Verb-paradigm slots** (`CMPLalt`, `INCMP`, `IMP-re`, `SVC`, `SEQ`) — *option A (recommended)* | Same as #12: one `example` each, `location` = slot name, value in `example/form[@lang=analang]/text`, twin in `example/field[@type='tone']` | ↔ | Recommended **because it is the only shape that gives the `_Pitch` twin a home** (and an audio slot and a translation slot). Caveat to flag to the user: A-Z+T's tone task iterates over locations, so 7 frames + 5 slots = 12 "frames" offered for tone sorting. Make it a user choice at import. |
| 13b | Verb-paradigm slots — *option B* | `entry/field[@type='Plural'\|'Imperative'\|'INCMP'\|…]/form[@lang='{analang}']/text` | ↔ | A-Z+T's native lexical-field shape: `Entry` is a `FieldParent`, and `Plural`/`Imperative` are already first-class in its own reporting (lift.py:1634-1638, plvalue/impvalue :3157-3161). Entry-level fields also carry audio forms (:1611-1626). **Loss:** no per-field tone slot → the `_Pitch` twin has nowhere to go except a parallel `Dk_INCMP_Pitch` field. |
| 14 | **Alternate-speaker forms** (`SpeakerA`, `Speaker2`) | `entry/field[@type='Dk_SpeakerA']/form[@lang='{analang}']/text` | ↔ | No native A-Z+T concept. A private-use tag (`{analang}-x-spkra`) on a citation form is tempting but **dangerous**: it would be picked up by `collect_and_sort_plausible_lang_codes` and, if `tag_is_valid` passes it, appear as a second analang (lift.py:1385-1387). Use a `Dk_` field. |
| 15 | **Notes** (`Notes`, `Note`, `Catatan`) | `entry/field[@type='Dk_Notes']/form[@lang='{G1}']/text` | ↔ | LIFT has `entry/note`, but **A-Z+T never reads or writes `<note>`** — it is absent from `LiftURL.setchildren` (lift.py:4553-4570). Use a field so A-Z+T's generic field machinery (:1473-1485) surfaces it. **Preserve whitespace**: sample record has `nasalized vowels;   double  spaces in source preserved` — do not run the C# `Flatten()` collapse (that exists only because PA's SFM reader is line-based; LIFT has no such constraint). |
| 16 | **Record flags** (`kosong`=`x`, `Category`=`DUPLICATE`) | *(no LIFT node — drives the skip decision)* | D→A | Must be recorded in the sidecar so the skipped rows can be re-emitted on export instead of vanishing. |
| 17 | `qvp_acoustic_data_` nested blocks | *(none)* | — | Structurally excluded — `DekerekeFile.cs` skips any element with children. **Stash verbatim in the sidecar keyed by Reference** or lose Praat measurements permanently. |
| 18 | *(any unmatched column, e.g. `Orth.practice`)* | `entry/field[@type='Dk_{column}']/form[@lang='{analang}' or '{G1}']/text` | ↔ | Column names with `-` and `.` are safe inside `field[@type="…"]` predicates. Keep **one form-lang per field** so `getlang` resolves via `len(possibles)==1` (lift.py:2694) and never raises (:2702-2707). |
| — | **A-Z+T's OWN data — no Dekereke home** | | | |
| 19 | *(none)* | `entry/sense/field[@type='{profile} {ftype} verification']/form[@lang='{analang}-x-py']/text`; also `'{ftype} primitive verification'` and `'{ftype} verification'` | **A→D: DO NOT** | The whole sort record: a `str()`-ified Python list of `check=group` codes (`'#C=C'`, `'C1=g3'`, `'syls=2'`) — lift.py:3610-3616 (key), :3617-3650 (storage), :3664-3668 (code shape). Physically expressible as a Dekereke column; semantically it would appear as an editable garbage column in Dekereke's UI and could be corrupted by a user. **Exclude from export.** This is the structural reason the LIFT file must be the master. |
| 20 | *(none)* | `entry/@guid`, `entry/sense/@id`, `entry/@id`, `entry/@dateCreated`, `entry/@dateModified` | A→D: drop | Generated fresh on import (lift.py:317-332, :345-349). `entry/@id` = `{headword}_{guid}`. Dekereke's `Reference` is the only stable key it has. |
| 21 | *(none)* | `entry/sense[2..n]` | A→D: lossy | A Dekereke record is one flat row. Multiple senses ⇒ either drop all but the first, or explode to N rows and break `Reference` identity. |
| 22 | *(none)* | `entry/sense/illustration/@href`, `entry/trait[@name='morph-type'][@value='stem']`, `form/annotation[@name][@value]` | A→D: drop | lift.py:4102-4104, :4100 (morphtype), :1601-1607 (form annotations). |
| 23 | *(none)* | `entry/sense/field[@type='SILCAWL']/form[@lang='{G1}']/text` | A→D: as a column | The CAWL line number (lift.py:4088-4099, :3387). Round-trips fine as an invented Dekereke column if the user wants it. |
| 24 | *(none)* | `program.alphabet` / macrosort glyphs | — | **Not in LIFT at all** — project settings. Neither format carries it. |

---

# 3. Heuristic cue table

## 3a. Rules the C# `AutoMapper` actually implements

Exact case-insensitive **equality** (`string.Equals(…, OrdinalIgnoreCase)`) — **not** substring or regex. Fields claim in table order; within a field, the earlier cue wins; a column is claimed at most once; a target is filled at most once.

| Priority | Target role | Cues, in order (EN / **ID**) |
|---|---|---|
| 1 | Phonetic | `Phonetic`, **`Fonetik`**, `IPA` |
| 2 | Reference | `Reference`, `Ref`, `No`, **`Nomor`** |
| 3 | Tone | `Pitch`, `Tone`, **`Nada`**, `Surface_Melody` |
| 4 | Phonemic | `Phonemic`, **`Fonemik`** |
| 5 | Gloss (primary) | `Gloss`, **`Arti`**, `EnglishGloss` |
| 6 | Gloss (secondary) | `IndonesianGloss`, `Gloss2`, **`ArtiIndonesia`**, `NationalGloss` |
| 7 | Part of speech | `Category`, `POS`, `PartOfSpeech`, **`Kategori`**, **`KelasKata`** |
| 8 | Orthographic | `Orthography`, **`Tulisan`**, **`Ejaan`** |
| 9 | Audio file | `SoundFile`, `Audio`, `Sound`, **`Rekaman`** |
| 10 | Note | `Notes`, `Note`, **`Catatan`** |

Behavioural invariants worth porting verbatim:

| Rule | Consequence | Pinned by |
|---|---|---|
| Ordered claim, one column per target | `Orthography` beats `Tulisan`; `Pitch` beats `Nada`, and `Nada` stays unclaimed | `AutoMapperTests.Map_OrthographyBeatsTulisan_WhenBothPresent`, `…_PitchBeatsNada_AndNadaStaysUnclaimed` |
| Unmatched is normal | Frames/`_Pitch` twins deliberately unmapped for PA | `AutoMapperTests` asserts `Does.Not.Contain("goodX")`, `("Xbad")` |
| Re-map on reload adds only, never changes | User's manual choice survives new Dekereke columns forever | `AutoMapper.MapNewColumns` |
| No Phonetic ⇒ hard error | Refuse the import rather than produce a broken project | `ColumnMap.Validate` |
| Never prompt except on first contact / unmappable phonetic / explicit request | Reload must be silent | HANDOFF.md trap 6 |

## 3b. Rules the Python port must ADD (proposed — not in the C# code)

PA had no home for these; A-Z+T does.

| Cue pattern | Role assigned | Evidence in sample data | Risk |
|---|---|---|---|
| Name ends `_Pitch`, prefix is another known column | tone twin of that column | `CMPLalt_Pitch`, `INCMP_Pitch`, `IMP-re_Pitch`, `SVC_Pitch`, `SEQ_Pitch`, `Xwater_Pitch`, `Xneg_Pitch`, `Xbad_Pitch`, `goodX_Pitch`, `whiteX_Pitch` | 2 of 7 frames have no twin — must not require pairing |
| Name ends `_Pitch`, prefix unknown | standalone tone column | — | low |
| Contains a capital `X`, unclaimed, not `_Pitch` | elicitation frame; `X`'s position = the word's slot in the frame | `goodX`, `whiteX`, `Xbad`, `Xneg`, `pigX`, `Xpig`, `Xwater`, `Xstraight`, `Xbig`, `Xbroken`, `Xnearby`, `Xstrong`, `Xlike` | false positive on any legitimate column containing `X` — make it confirmable in the dialog |
| Matches a paradigm-label set: `CMPL*`, `INCMP*`, `IMP*`, `SVC`, `SEQ`, `PL`, `PERF`, **`Jamak`**, **`Perintah`** | verb-paradigm slot | `CMPLalt`, `INCMP`, `IMP-re`, `SVC`, `SEQ` | must be prefix-matching (`CMPLalt`, `IMP-re`), unlike rule 3a's equality |
| `SyllableProfile`, `Profile`, `CVProfile`, **`PolaSuku`** | CV profile (→ `_MT` form) | `SyllableProfile` | low |
| `Speaker*`, **`Penutur*`**, or a bare personal name | alternate-speaker form | `SpeakerA`, `Speaker2` | personal names are unguessable — dialog only |
| `*Class`, `Inflection*`, `Type`, **`Kelas*`** | POS subclass (only the first gets the native trait) | `Type`, `VerbClass`, `Inflection_Class` | three-way collision is real in the sample |
| **`kosong`**, `empty`, `skip`, `omit`; or POS value `DUPLICATE` | record-skip flag | `kosong`=`x`; `Category`=`DUPLICATE` | must be *confirmed*, never silent |
| `Orth*`, **`Ejaan*`**, **`Tulisan*`** beyond the first | secondary orthography → `Dk_` field | `Orth.practice`, `Tulisan` | low |

---

# 4. What is lost

## 4a. Dekereke → A-Z+T (small, and mostly recoverable by stashing)

1. **`<qvp_acoustic_data_>` acoustic measurements** (`V1T:0.212,V1F1:412,V1F2:1930`) — no LIFT node exists for them; the reference reader drops every element with children. *Recoverable only via sidecar.*
2. **Column inventory and column ORDER** — Dekereke's UI order is the first-seen element order. LIFT preserves neither. *Sidecar.*
3. **Empty-vs-absent** — Dekereke emits a self-closing element for every column in every record; LIFT just omits. Export must re-emit the full column set per row, so the inventory must be known. *Sidecar.*
4. **Records with empty `Phonetic`** (`Reference` 0012 in the full sample) — cannot become a LIFT entry; skipped, and gone from any export. *Sidecar the whole raw row.*
5. **Second and third orthography / tone / subclass columns** — A-Z+T has one native slot each; the surplus survives only as opaque `Dk_` fields with no A-Z+T behaviour attached.
6. **`<sound_file_path>`** — A-Z+T's audio folder is hard-coded `<lift_home>/audio`; the Windows path is unrepresentable. Audio files must be **physically copied**. *Sidecar the path.*
7. **Per-column sound-file suffix mappings** (`Phonetic→-phon`, `Speaker2→-sp2`) — several takes per row collapse to one audio form unless each derived filename is materialised.
8. **Syllabification dots** in `Phonemic` (`se.wa`) — carried as literal text only, invisible to A-Z+T's syllable machinery.
9. *Not lost:* encoding. UTF-16LE+BOM / UTF-8+BOM / bare UTF-8 all decode to the same Unicode — provided the **raw byte stream** goes to the parser and is never pre-decoded (HANDOFF.md trap 1; `DekerekeFile.cs` header comment). `lxml.etree.fromstring(open(p,'rb').read())` handles all three; verified on both samples.

## 4b. A-Z+T → Dekereke (large, and mostly irrecoverable)

1. **The entire sort/verification record** — `field[@type='{profile} {ftype} verification']` etc., stored as a Python-list string in an `-x-py` form. Expressible as a column, but it would be user-editable garbage in Dekereke's UI. **Do not export.** *This is why the LIFT must remain the master copy.*
2. **UF tone and per-frame surface tone groups** — expressible only as invented columns; the `_MT` vs plain (machine vs ear-confirmed) distinction has no column-level encoding, so re-import cannot tell them apart.
3. **`guid` / `sense@id` / `dateCreated` / `dateModified`** — no home; identity collapses onto `Reference` alone.
4. **Second and subsequent senses** of an entry — a Dekereke record is one flat row.
5. **Multiple glosses in one glosslang** — `sense.glosses[lang]` is a list; must be joined into one cell.
6. **The gloss-vs-definition distinction** — one column per language on the Dekereke side. (A-Z+T's own `addentry` writes them identically, so this only bites on FLEx-edited data.)
7. **`illustration/@href`, `trait[@name='morph-type']`, `{ps}-infl-class` beyond the first axis, `form/annotation[@name][@value]`.**
8. **Per-frame translations** (`translation[@type='Frame translation']`) — frame columns have no translation slot.
9. **The five parallel form-langs per form-parent** (`-x-ipa`, `-x-tone`, `-x-cvprofile`, `-x-py`, `-Zxxx-x-audio`, each ×`_MT`) — Dekereke's model is one value per column, so each needs its own invented column, and the tag semantics are lost.
10. **`program.alphabet` / macrosort glyphs** — never in LIFT at all; out of scope for both directions.

## 4c. Round-trip design that preserves what it can

**Two stores, split by who edits the data.**

**(i) Sidecar `<lift-basename>.dekereke.xml`, beside the `.lift`** — for machine data no linguist will hand-edit. Direct precedent: the PA add-on's `<project>.DekerekeMappings.xml` (`ColumnMap.cs`, `MappingStore`), which is "written and read only by this tool; the user never edits it." Zero FLEx exposure, zero A-Z+T exposure. Holds:

```xml
<dekerekeSource sourcePath="…/SampleLang_full.xml" encoding="utf-16-le-bom">
  <soundFilePath>C:\SampleLang\audio</soundFilePath>
  <columns>            <!-- first-seen order; drives export column order -->
    <column name="Reference" role="reference"/>
    <column name="Gloss" role="gloss" lang="en"/>
    <column name="goodX" role="frame" pitchTwin="goodX_Pitch"/>
    …
  </columns>
  <soundSuffixes><map column="Speaker2" suffix="-sp2"/></soundSuffixes>
  <skipped ref="0012" reason="empty-phonetic"><!-- raw <data_form> verbatim --></skipped>
  <opaque ref="0003"><qvp_acoustic_data_>…</qvp_acoustic_data_></opaque>
</dekerekeSource>
```

**(ii) In the LIFT itself — the minimum that must travel with each entry.** Only the **Reference** is truly required, because it is the row identity for re-export and for a *second* import (update rather than duplicate). Plus `Dk_{column}` fields for any unmapped column a linguist might legitimately edit.

Is there a LIFT slot for this that won't upset FLEx? **Yes, and A-Z+T already relies on it**: LIFT's `<header><fields><field tag="…"><description>` block is precisely the "declare a custom field" mechanism, and FLEx materialises a declared custom field rather than dropping it. So:

```xml
<lift>
  <header><fields>
    <field tag="Dekereke-Reference">
      <description><form lang="en"><text>Record key from the source Dekereke database.</text></form></description>
    </field>
  </fields></header>
  <entry guid="…">
    <field type="Dekereke-Reference"><form lang="en"><text>0003</text></form></field>
    …
```

This is byte-for-byte the shape of A-Z+T's own `SILCAWL` field (lift.py:4088-4099), moved from sense level to entry level because a Dekereke row is an entry. A-Z+T tolerates it without any code change: `getfieldnames` (:1473-1485) collects arbitrary entry-level field types generically, and `getlang` (:2694) resolves a single-form field by `len(possibles)==1`. **Confidence caveat:** the FLEx side of this is reasoned from the LIFT spec's purpose for `header/fields`, not verified against a live FLEx import — verify before shipping. If FLEx does object, fall back to keying everything by `Reference` in the sidecar, at the cost of desynchronising whenever a user adds entries in FLEx or A-Z+T.

## 4d. Shape of the transform (given the XSLT constraint)

Because column names vary per database, the stylesheet cannot match on element names. The workable shape, following the in-repo precedent at `io_put/xlp.py:115-140`:

1. `raw = open(path,'rb').read()` → `lxml.etree.fromstring(raw)`. **Never pre-decode** — the UTF-16 sample carries `encoding="utf-16"` in its declaration and a decoded `str` makes the parser throw.
2. Read the union of child element names in first-seen order, skipping any element with children (drops `qvp_acoustic_data_`).
3. Auto-map (§3a + §3b) → user confirms in a dialog → persist to the sidecar.
4. Emit the map as a small XML document (or as `xsl:param`s) and run `lxml.etree.XSLT` over `phon_data`, generating `entry`/`sense`/`example` per §2.
5. **The one place XSLT alone breaks down:** `entry/@guid` and `sense/@id` need fresh 8-4-4-4-12 hex GUIDs, and `entry/@id` = `{headword}_{guid}` (lift.py:317-332, :345-349). XSLT 1.0 (all lxml offers) has `generate-id()` but no UUID generator. Either register a Python extension function on the XSLT context, or pre-inject a `guid` attribute per `data_form` in a Python pass before the transform. The latter is simpler and keeps the stylesheet pure.

## Open questions
- Does FLEx actually materialise a header-declared custom field (`lift/header/fields/field[@tag='Dekereke-Reference']` + `entry/field[@type='Dekereke-Reference']`) rather than warning or dropping it? Reasoned from the LIFT spec's stated purpose for `header/fields`, but NOT verified against a live FLEx import — this is the one claim in the round-trip design that needs a real test before shipping, since Kent's merge criterion will include FLEx-safety.
- Should Dekereke verb-paradigm columns (CMPLalt/INCMP/IMP-re/SVC/SEQ) import as EXAMPLES (row 13, keyed by `field[@type='location']`, which gives their `_Pitch` twins a native home) or as ENTRY-LEVEL FIELDS (row 13b, A-Z+T's native `Plural`/`Imperative` shape, but no tone slot)? Examples is technically better but inflates A-Z+T's tone-frame list from 7 to 12 for the full sample. Probably a per-import user choice — needs Seth's judgement on the Fayu workflow.
- Which A-Z+T lang tag should hold Dekereke's `Phonetic` when the database ALSO has a `Phonemic` column? A-Z+T's `-x-ipa` tag means *phonetic* (langtags.py:43), so the natural pair is Phonetic→`citation/form[@lang=analang]` + Phonemic→`Dk_` field, but a project treating the analang tag as orthographic would want the reverse. Needs a project-level setting, not a heuristic.
- Is `SpeakerA`/`Speaker2` better modelled as a private-use analang variant (`{analang}-x-spkra`) than as an opaque `Dk_` field? The variant would make the alternate transcription sortable by A-Z+T, but `collect_and_sort_plausible_lang_codes` (lift.py:1385-1387) would surface it as a second analang if `langtags.tag_is_valid` accepts it. Whether that is a feature (comparing speakers) or a bug (spurious analang in the project picker) is a design call.
- Does Dekereke itself re-open an XML file that this tool writes? The C# reference implementation only ever READS Dekereke XML — nothing in `/Users/Seth/dekereke-pa-data-source/src/` writes it. Rod Casali's parser may impose constraints (element order, a required column set, the `-DkUserSettings.xml` sibling) that the samples do not reveal. The A→D direction should be treated as unvalidated until a written file is opened in real Dekereke.
- Should the `_MT` (machine) convention apply to imported Pitch/Nada/Surface_Melody unconditionally, or should the import dialog let a user assert 'these were confirmed by ear in Dekereke, import as human-confirmed'? Defaulting to `_MT` is safe (lift.py:3296-3303), but for Seth's own Fayu database the Dekereke pitch annotations ARE ear-confirmed, and forcing a full re-sort in A-Z+T would be a significant cost.