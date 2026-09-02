# Adversarial verification pass 1

## Bottom line

The investigation's core thesis survives adversarial checking: A-Z+T's profile engine, syllable model and tone model are genuinely language-general, and I independently reproduced the profiling results by instantiating RegexDict directly. Of ~37 claims, 30 are CONFIRMED (several understated), 5 OVERSTATED, 1 WRONG. But it got the two most important things backwards. (1) It called the `Sense.cawln` AttributeError 'latent'; I reproduced it — loading a Fayu LIFT with no CAWL fields raises at io_put/lift.py:678 during init_post_analang, is caught by backend/core/file_parser.py:29-35 as a 'non-XML problem', and re-raised. A-Z+T on current main cannot open a Papua database at all, which moots every finding downstream of it. (2) It asserted Fayu's inventory is 'fully covered by the hardcoded segment lists'; β and ɸ are absent from io_put/lift.py's inventory (which does carry ɓ ɗ ɖ kp gb), so any word with β profiles as 'Invalid', and the runtime add-a-grapheme escape hatch addtoCVrxs has zero callers. Smaller corrections: 'iau' is not Iau's code (Iau is 'tmu', valid and in the bundled lineage data), and tag_is_valid also filters analangs on every load — a migration hazard the investigation missed; the NC/CG defaults are not the prenasal blocker (polygraph confirmation is — verified across the four-cell matrix); the CAWL doc footer is on 17 of 35 docs, not 'every one of ~15'; crowdin.yml names no project (the badge in docs/README.md:1 does); and the langtags.json/ethnologue counts (28099, 7618) are wrong or mis-scoped. The format-string bug is real and worse than stated: the one correct copy sits on a class that is commented out of the shipped task list.

### CONFIRMED: The CV-profile engine imposes no CV(C) template; profiles are validated as a character SET, not a shape grammar. Empirically 'tiaure'→'CVVVCV', 'uai'→'VVV', 'oai'→'VV', 'kirik'→'CVCVC', 'ᵐbou'→'CV', 'kwai'→'CV'.

Reproduced independently. backend/core/profiles.py:34 profilelegit list and :323-324 `if not set(self.profilelegit).issuperset(profile): profile='Invalid'` are exactly as quoted (claim cited :333 — actual :323-324). I instantiated utilities/rx.py RegexDict with a Fayu-like sdict and got, at DEFAULTS (NC=CC, CG=CC, VV=VV): tiaure→CVVVCV, kirik→CVCVC, ᵐbou→CV, kwai→CV. One internal inconsistency: 'uai'→VVV and 'oai'→VV cannot both hold in one configuration — VVV requires 'ai' NOT be a confirmed digraph, VV requires it be. With 'ai' as a digraph I get uai→VV; without, uai→VVV and oai→VVV. Each is reproducible, but they came from two different inventories presented as one run.

_evidence:_ scratchpad t1.py/t2.py runs against /Users/Seth/GIT/azt/utilities/rx.py:289 RegexDict; /Users/Seth/GIT/azt/backend/core/profiles.py:34,323-324

### WRONG: Fayu's inventory (i u o ɛ a, β) is fully covered by the hardcoded segment lists and the alphabet feature tables.

The VOWEL half is right; the CONSONANT half is false. 'β' and 'ɸ' are NOT in the hardcoded segment inventory in io_put/lift.py:1795-1977 (which does contain ɓ, ɗ, ɖ, kp, gb, ɣ, ᵐb — an African inventory). Only backend/core/alphabet.py:44 has 'β':(0,1,1), and that table is used solely for alphabet-booklet page ORDERING, not for segmentation. db.s is built as hypotheticals ∩ forms-present (io_put/lift.py:1988-1993 via utilities/rx.py:222 inxyz), so a glyph absent from the hardcoded list is never classified. I verified the consequence: profileofform('βa')→'βV', profileofform('kaβa')→'CVβV', and profiles.py:323-324 then rewrites both to 'Invalid'. Same for a bare superscript nasal: 'ᵐba'→'ᵐCV'→Invalid unless 'ᵐb' is a confirmed polygraph. Worse, the only in-code escape hatch, backend/core/profiles.py:231 addtoCVrxs ('Add a new grapheme while running, so we don't have to restart'), has ZERO callers anywhere in the repo.

_evidence:_ grep of io_put/lift.py segment block for 'β'/'ɸ' → False; scratchpad t3.py output; grep -rn addtoCVrxs → only the definition at backend/core/profiles.py:231

### CONFIRMED: The syllable model treats a profile's syllable count as a RANGE (vowel-sequences .. individual vowels), derives everything from three theory-neutral primitives (#C/C#/syls), and allows C-clusters and V-runs up to 3 with a free-entry escape hatch.

All quoted code verified verbatim: backend/core/analysis_inputs.py:200-206 profile_syllable_range; :183-199 profile_fits_class docstring ('CVVCV' is legitimately 2 or 3 syllables); :322-334 word_initial/word_final/syllable_count with max(n,1); :162-166 compose_profile_class; :306-341 legal_profiles_for_class with percap=2 and 'Anything rarer is set by hand on the free-entry page'; :401-407 PROFILE_CONSTRAINT/_profile_segments comments. This is the strongest claim in the set and it holds.

_evidence:_ /Users/Seth/GIT/azt/backend/core/analysis_inputs.py:162-166, 183-206, 306-341, 395-415

### CONFIRMED: Tone is theory-neutral: same/different piles, no H/L/M constants, Chao 5-level letters with real contour interpolation in the beep synthesiser.

backend/reporting/generator.py:246-249 report text verified verbatim ('It does not pretend to tell you what the values of those groups are'); frontend/transcriber.py:135 tonechars=['[','˥','˦','˧','˨','˩',']'] verified; io_put/sound.py:528-556 pitchdict + `if n+1 < len(syl) and c != syl[n+1]` → numpy.arange interpolation verified. backend/core/lexicon.py:2041 `class Tone(Senses)` verified. No H/L/M tone constants found.

_evidence:_ /Users/Seth/GIT/azt/backend/reporting/generator.py:246-249; frontend/transcriber.py:135; io_put/sound.py:520-556; backend/core/lexicon.py:2041

### CONFIRMED: Tone sorting IS organised by (lexical category × syllable profile) with per-ps 'tone frames' — the Snider / Kutsch Lojenga methodology — but the frames are user-authored, not built in.

docs/RATIONALE.md cites Kutsch Lojenga 1996, Snider 2014/2018, Marlo 2013 'Verb tone in Bantu languages' (claim's line range 12-18 is roughly right; citations run ~10-18). backend/core/sorting_engine.py:239 `frames=self.program.toneframes.get(self.ps)` verified. settings/tone_frames.py is a 7-line bare ConfigManager subclass with no defaults, verified in full. tasks/tasks.py:686 ToneFrameDrafter collects before/after text per language.

_evidence:_ /Users/Seth/GIT/azt/docs/RATIONALE.md:1-18; backend/core/sorting_engine.py:236-243; settings/tone_frames.py (whole file); tasks/tasks.py:686+

### OVERSTATED: Prenasalised stops and labialised Cw are first-class; by DEFAULT NC and CG are interpreted as TWO consonants, which must be changed per project for a language with unit prenasalised stops or labialised consonants.

The defaults are exactly as stated (backend/core/profiles.py:156-163 → NC='CC', CG='CC', CS='CC'; utilities/rx.py:434 interplist; io_put/lift.py:1886-1889 prenasal list with the 'always single consonants' comment; io_put/lift.py:1910-1919 auto-'w' loop). But the second half is wrong as a general statement: the NC/CG SETTINGS are irrelevant whenever the sequence is a confirmed polygraph. I tested all four cells: with 'mb' confirmed as a D-digraph and NC='CC' (default), 'mba'→CV; with 'mb' not a digraph and NC='CC', 'mba'→CCV; with NC='C', 'mba'→CV. So the NC setting only bites for prenasals written with plain letters that the user declined as digraphs; a project using ᵐb/ⁿd superscripts, or accepting the mb/nd/ŋg digraph defaults, needs no NC change at all. Conversely 'kw' is only 'CV' because the auto-'w' loop manufactures it as a C-digraph candidate — again polygraph confirmation, not the CG setting.

_evidence:_ scratchpad t4.py; /Users/Seth/GIT/azt/backend/core/profiles.py:156-163; utilities/rx.py:414-460; io_put/lift.py:1885-1919

### CONFIRMED: The digraph/polygraph CANDIDATE list is a closed, hand-curated list shaped by English, French and Cameroonian orthographies; missing 'ia','ua','ao','io','iu','ui'; the only UI escape hatch is a mailto.

io_put/lift.py:1960-1968 x['Vdg'] verified verbatim including the '#requested by bfj', '#requested by Jane', '#For English', '# for French' comments; none of ia/ua/ao/io/iu/ui/eo/uo is present. docs/POLYGRAPHS.md:6 quote verified. The mailto is at frontend/config/settings_ui.py:119-124 (claim gave no line; it is there, `mailto:{Email}?subject=New trigraph or digraph to add`). Note the list is candidates-in-data only: a candidate never appearing in the data is never offered, and one appearing but absent from the list can never be declared a single segment.

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1960-1969; docs/POLYGRAPHS.md:6; frontend/config/settings_ui.py:112-124

### CONFIRMED: The VV interpretation setting is a single GLOBAL binary applied to any two adjacent vowels, but the UI describes it as applying only to the same vowel letter twice.

Confirmed, with a corrected line number and one addition. The UI string is at frontend/ui_shell.py:4036, not :4056 ('How to interpret the *same* vowel letter twice in a row (VV)?'); the option pair is at :4060. Empirically with interpret['VV']='V': ai→V, ao→V, bau→CV, tiaure→CVVCV — no same-letter constraint. ADDITION: the collapse is capped at TWO vowels, because interpreted() emits one base group plus exactly one optional group (utilities/rx.py:445-459) — so 'uai' stays 'VV' even with VV=V. utilities/rx.py:742-743 author TODO verified.

_evidence:_ /Users/Seth/GIT/azt/frontend/ui_shell.py:4036,4060; utilities/rx.py:434-460,742-743; scratchpad t1.py/t2.py 'VV=V' rows

### CONFIRMED: There is a live crash in the primary word-collection button for ANY database missing CAWL tags: WordCollection.dobuttonkwargs formats '{}' with .format(count=…) → IndexError, swallowed by a bare except in ui_shell, so 'Add a Word' never renders.

Confirmed and UNDERSTATED. The defect is at backend/core/lexicon.py:731 and tasks/tasks.py:578 and :664. tasks/tasks.py:537 is the correct `{count}` version — but its class, WordCollectnParse, is COMMENTED OUT of the shipped task list (tasks/chooser.py:177). The two tasks actually offered for data collection are WordCollectionCitationwRecordings (MRO → backend/core/lexicon.py:725, the `{}` version) and WordCollectnParsewRecordings (tasks/tasks.py:572, the `{}` version) — so no shipped collection task escapes the bug. `'{}'.format(count=3)` → IndexError verified. Swallowing verified at frontend/ui_shell.py:1100-1105 (`except Exception as e: log.error(f"Problem: {e}")`). getcawlmissing (tasks/chooser.py:297-303, `for i in range(1700)`) is called unconditionally from whatsdone (:342).

_evidence:_ /Users/Seth/GIT/azt/backend/core/lexicon.py:731; tasks/tasks.py:537,578,664; tasks/chooser.py:174-182,297-303,342; frontend/ui_shell.py:1100-1105

### CONFIRMED: Sense.cawln is referenced but never assigned — a latent AttributeError in slicebyerror(), which runs on every database load.

Confirmed, and it is NOT merely latent — I reproduced it. I wrote a two-entry Fayu LIFT (lang='fau', English glosses, no CAWL fields) and called lift.LiftXML(path, analang='fau') under python3.13: AttributeError: 'Sense' object has no attribute 'cawln' at io_put/lift.py:678, raised from init_post_analang line 87. Sense (io_put/lift.py:3138, `class Sense(Node,FieldParent)`) has no __getattr__ and no `self.cawln=` anywhere; the live attribute is word_list_n. imgselectiondir defaults to None (:3753) and is only populated inside getglosses (:3163-3190) when a matching images/toselect/ directory exists — so any sense with no CAWL number and no gloss-matching image directory hits the crash. It is NOT silently swallowed: backend/core/file_parser.py:29-35 catches it as `except Exception`, shows 'There seems to be a (non-XML) problem loading your database', clears the default filename, and re-raises. This is a hard door-slam on a Papua project, not a cosmetic defect.

_evidence:_ scratchpad load.py traceback; /Users/Seth/GIT/azt/io_put/lift.py:87,678,684,3138,3163-3190,3753; backend/core/file_parser.py:14-35

### CONFIRMED: Creating a NEW A-Z+T project necessarily seeds it from the Comparative African Wordlist; WordListTemplate has exactly one concrete subclass; SILCAWL.lift is not in this repo and is cloned at runtime into the parent of the azt checkout.

frontend/ui_shell.py:3170 `t=templates.CAWL(self.program,analang=self.code)` verified; backend/core/templates.py:84 `class CAWL(WordListTemplate)` is the only subclass; io_put/cawl.py:11 stockCAWL path verified. .gitignore:17 `lift_templates/SILCAWL`; `ls lift_templates/` → only SILCAWL_ReadMe.md, SILCAWL_update.py, __init__.py. utilities/sister_repos.py:63-68 spec verified; suite_root() = os.path.dirname(azt_root()) at :40-41, and _candidates() joins suite_root()/name at :97 — so the clone lands in /Users/Seth/GIT/lift_templates, which does not exist on this machine. ensure() never pulls (:205-207 docstring) and every failure path returns False (:196-201).

_evidence:_ /Users/Seth/GIT/azt/frontend/ui_shell.py:3170,3286; backend/core/templates.py:84-99; io_put/cawl.py:10-26; utilities/sister_repos.py:40-41,63-68,91-100,180-201,205-216; .gitignore:17

### CONFIRMED: Automatic illustration filling is keyed to CAWL numbers via a hardcoded LIFT field name; user-supplied pictures still work.

io_put/lift.py:70 `self.word_list_field_name='SILCAWL' #make this configurable` verified (the sibling `# self.word_list_n_attr='cawln'` is commented out at :69). io_put/lift.py:139-145 get_img_resolver raises ValueError for any other name. backfill_illustration returns False immediately `if not self.word_list_n` (:3398-3399). illustrationURI privileges 'File in lift node' (:3430-3441) and local_only skips the GitHub resolver (:3462-3464), so a FLEx-attached picture works with no CAWL tag; backend/core/alphabet.py:431,489,901,945,1113 all call illustrationURI(local_only=True).

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:69-70,135-146,3392-3399,3429-3466; backend/core/alphabet.py:431,489

### CONFIRMED: The root parser assumes concatenative prefix/suffix morphology recovered as the longest common CONTIGUOUS substring of two forms, and handles only nouns-with-plurals and verbs-with-imperatives.

backend/parser.py:678-694 roothypgenerator uses difflib.SequenceMatcher(...).find_longest_match() and returns contiguous subsets, verified. backend/parser.py:250-274 getfields with the three branches and 'This entry has neither plural nor imperative?? skipping.' verified. settings/__init__.py:156-158 plopts/impopts verified verbatim. guess_nominalps/guess_verbalps at settings/__init__.py:726-750 verified, defaulting to 'Noun'/'Verb'; note the option lists are English/French/Spanish only (n_opts includes 'Sustantivo', no Indonesian 'Nomina'/'Kata benda', no 'Verba'). docs/README.md:13 concession verified verbatim. Infixation, reduplication and ablaut/tone-only plurals are all out of reach, as implied.

_evidence:_ /Users/Seth/GIT/azt/backend/parser.py:250-274,678-694; settings/__init__.py:156-158,726-750; docs/README.md:13

### OVERSTATED: langcodes reports tag_is_valid('iau')=False and A-Z+T hard-gates its language chooser on that — but 'fau' (Fayu) is valid and IS in the bundled Ethnologue lineage data as Lakes Plain > Tariku > West. 'iau' (Iau) is absent from both bundled datasets. data/langtags.json has 28099 tags.

The mechanism is confirmed and is in fact BROADER than claimed, but the language identification is wrong and two counts are wrong. Confirmed: backend/langtags.py:40 `tag_is_valid=langcodes.tag_is_valid`; frontend/ui_shell.py:3145 gates the button; backend/core/templates.py:34-37 verify_code. langcodes 3.5.1 / language_data 1.4.0 (both unpinned, requirements.txt) → tag_is_valid('iau')=False, ('fau')=True/'Fayu'. data/ethnologue_language_relationships.py has fau with lineage ['Lakes Plain','Tariku','West']. WRONG: 'iau' is not Iau's code and is not an ISO 639-3 code at all — Iau is 'tmu', tag_is_valid('tmu')=True, and it IS in the bundled lineage data as Lakes Plain > Tariku > Central. So the gate does not reject Iau; it rejects a non-standard tag. Counts: data/langtags.json holds 9586 records / 37640 distinct tags, not 28099; the lineage file has 10711 entries of which 7618 carry a language code (the claim's 7618 refers to the latter). BROADER than claimed: io_put/lift.py:1389 also filters db.analangs through tag_is_valid on every load, so an existing LIFT with lang="iau" loses that analang entirely — this is a data-visibility problem, not just a new-project gate.

_evidence:_ python3 langcodes checks; /Users/Seth/GIT/azt/backend/langtags.py:40; frontend/ui_shell.py:3145; backend/core/templates.py:34-37; io_put/lift.py:1389,1404,1439; data/langtags.json; data/ethnologue_language_relationships.py

### CONFIRMED: No ASR model coverage exists for Fayu or Iau; the demo language gnd has full MMS support; degradation is graceful and language-independent recognisers still work.

data/mms_language_support.py holds 4022 entries; data['gnd']={'name':'Zulgo-Gemzek','asr':True,'tts':True,'lid':True,...}; data.get('fau'), .get('iau') and .get('tmu') are all None; data['ind'] is fully supported. backend/asr.py:145-157 logs "No '<lang>' MMS adapter for <repo>; skipping this language" and continues. backend/asr.py:19-32 REPO_MODELNAMES registers 'allosaurus' and 'neurlang/ipa-whisper-base' (plus katyayego phoneme models), none of which needs a per-language adapter.

_evidence:_ /Users/Seth/GIT/azt/data/mms_language_support.py; backend/asr.py:19-32,145-158

### CONFIRMED: There is a 'depressor consonant' segment class (D) defined as the voiced obstruents; it is off by default and analytically inert unless enabled.

backend/core/profiles.py:33 profilesegments; utilities/rx.py:390 'N for nasals, D for depressors'; io_put/lift.py:1906-1908 `elif 'vd' in stype: consvar='D'`; frontend/ui_shell.py:4022-4025 the D question. Defaults: backend/core/profiles.py:145-155 sets distinguish[var]=False for every var, then forces True only for '<','=','.' and False for 'ː' and the combining grave. Verified verbatim.

_evidence:_ /Users/Seth/GIT/azt/backend/core/profiles.py:33,145-155; utilities/rx.py:390; io_put/lift.py:1905-1908; frontend/ui_shell.py:4022-4025

### CONFIRMED: No ATR, vowel-harmony, 7-vowel or nasal-vowel-system assumptions exist; vowel handling is IPA-general; nasal vowels are opt-in.

grep for ATR / 'advanced tongue' / 'vowel harmony' across all .py and .md returns zero relevant hits (the only 'harmony' matches are harmony_sync.py, an orphan sync module). io_put/lift.py:1931-1957 x['V'] contains 60+ glyphs including all five Fayu vowels (a e i o u ɛ) plus ɔ ə ɨ ʉ ɯ ɤ ø and decomposed/precomposed diacritic forms. VN is opt-in at frontend/ui_shell.py:4059. Caveat: this finding also asserts β coverage via backend/core/alphabet.py:44 — true for that table only, see the separate β correction.

_evidence:_ grep across repo; /Users/Seth/GIT/azt/io_put/lift.py:1931-1957; frontend/ui_shell.py:4059; backend/core/alphabet.py:44-62

### CONFIRMED: Bantu noun classes appear exactly once, as dead code that is never called.

io_put/lift.py:1784-1785 `def nc(self): nounclasses="1 2 3 4 5 6 7 8 9 10 11 12 13 14"` — assigns a local, returns None. Repo-wide grep for 'nounclass' finds only line 1785; no caller of .nc(). docs/LEXICAL_CATEGORIES.md discusses noun classes only as a labelling example.

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1784-1785; grep 'nounclass|\.nc(' → no callers

### CONFIRMED: The one live hardcoded ISO-code branch is an ASR-export special case for gnd; profiles.invalidchars is passed to RegexDict but never read; other gnd references are dev-only/demo/docs.

io_put/export.py:96 `self.no_verify_check=self.analang in ['gnd']` verified, consumed at io_put/lift.py:3719. export.Lexicon is reachable from the UI (tasks/tasks.py:49-53 switch, :133 `self.exportclass=export.Lexicon`). invalidchars: defined at backend/core/profiles.py:35, passed at :228, and grep shows the ONLY other occurrences in utilities/rx.py are the generic kwargs setattr comment at :745 and the `__main__` demo at :787/:795 — never read. settings/__init__.py:1115 'gnd':'Zulgo' is one row of a display-name table whose fallback is 'Language with code [{code}]' (:1129-1131).

_evidence:_ /Users/Seth/GIT/azt/io_put/export.py:96,105-114; io_put/lift.py:3719; tasks/tasks.py:49-53,133; backend/core/profiles.py:35,228; utilities/rx.py:745,787,795; settings/__init__.py:1115,1129-1131

### CONFIRMED: Interface languages ship as EN/FR/ES/AR/ZH and an empty Lingala; no Indonesian; the list is discovered dynamically from compiled .mo files; a public Crowdin project exists.

`ls translations/` → ar_SA, es_ES, fr_FR, ln_CD, zh_CN, azt.pot (+ README/compile/extract/workflow). Empty-msgstr counts match exactly: fr 1, es 31, ar 66, zh 722, ln_CD 1549. ln_CD ships a 464-byte azt.mo (header only). main.py:186-205 scans translations/*/LC_MESSAGES/azt.mo and builds self.interfacelangs. settings/__init__.py:1107-1108 already maps 'id'/'ind' → 'Indonesian'. ONE EVIDENCE ERROR: crowdin.yml does NOT name a project 'azt' — it reads project_id from $CROWDIN_PROJECT_ID (commented '856336'). The public project link is the badge at docs/README.md:1 → https://crowdin.com/project/azt.

_evidence:_ ls translations/; grep -c '^msgstr ""$' per .po; /Users/Seth/GIT/azt/main.py:186-205; settings/__init__.py:1107-1108; crowdin.yml:10-11; docs/README.md:1

### CONFIRMED: Segmental sorting is capped at 6 consonants and 6 vowels per word, with graceful degradation and an explicit invitation to raise the cap.

backend/core/analysis.py:1816-1831 verified verbatim, including 'If you need that, please let me know.' and `continue` (skip, not abort).

_evidence:_ /Users/Seth/GIT/azt/backend/core/analysis.py:1810-1834

### CONFIRMED: docs/TASKS.md overstates the CAWL gate: the code does not block other tasks on CAWL completion; the real gate is 200 collected citation forms.

docs/TASKS.md:6 quote verified verbatim. tasks/chooser.py:184-190 gates SortSyllables/SortV/SortC/SortT on doneenough['collectionlc'], set at :420 by `if citationsdone[lang] > 200`. The CAWL-dependent flag donew['collectionlc'] (:418, `and not len(self.cawlmissing)`) has exactly one consumer, frontend/ui_shell.py:2170 → makeeverythingok(). Confirmed.

_evidence:_ /Users/Seth/GIT/azt/docs/TASKS.md:6; tasks/chooser.py:184-190,417-421; frontend/ui_shell.py:2169-2170

### OVERSTATED: User-facing documentation is uniformly Africa-framed: every one of ~15 docs/*.md files carries the CAWL footer link.

The individual quotes are all verified verbatim: docs/HELP_PREREQUISITES.md:3 'across Africa'; docs/WORKSHOPS.md 'SIL Cameroon keyboard'; docs/WHYCOMPUTERS.md is a Zulgo/Cameroon case study including 'most Africans (that I have worked with) would prefer to use a computer'; docs/ws/VOWELS.md:13 'more than five vowels'. But the footer claim is false: 17 of 35 docs/*.md carry the comparalex CAWL link — under half. Among the files WITHOUT it are TASKS.md, WORKSHOPS.md, WHYCOMPUTERS.md, WESAY_FROM_SCRATCH.md, RATIONALE.md — i.e. several of the very files the claim quotes.

_evidence:_ grep -l comparalex.org docs/*.md → 17; ls docs/*.md → 35; docs/HELP_PREREQUISITES.md:3; docs/WORKSHOPS.md:23; docs/WHYCOMPUTERS.md:3,14; docs/ws/VOWELS.md:13

### CONFIRMED: The polygraph LWC default table is English/French only; other analysis languages fall through to an empty dict and the user is prompted per candidate.

backend/core/profiles.py:48-104 lwcdefaults has exactly two keys 'en' and 'fr'; the KeyError path logs 'It looks like neither your LWC ... nor your interface language ... has a set of digraph defaults, so not providing any' and returns {}. :117 assigns it per analang. Consequence verified at :119-133: any polygraph with no stored setting triggers askaboutpolygraphs(onboot=True), i.e. a Papua project is asked about every candidate found in its data.

_evidence:_ /Users/Seth/GIT/azt/backend/core/profiles.py:48-133

### CONFIRMED: Non-Latin script is partially anticipated: Tibetan glyphs are already in the hardcoded inventory; Charis is registered for PDF output.

io_put/lift.py:1801-1977 includes Tibetan ག ད བ ང ན མ ཉ and vowel signs ི ུ ེ ོ; x['=']=['=','-','།','་'] at :1976 and x['.']=['་'] at :1977. io_put/pdf_fonts.py:137 registers ('charis','Charis') and ('andika','Andika'), with :123 noting 'Charis alone is enough'.

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1801-1977; io_put/pdf_fonts.py:123,137-142

### CONFIRMED: The alphabet-booklet ordering feature uses phonetic feature tables that fall back to frequency ordering for unknown symbols, and they don't know implosives, prenasalised units, labial-velars or retroflexes.

backend/core/alphabet.py:52-64 _CONS_FEAT covers exactly p b m ɸ β f v θ ð t d n s z ts l r ɾ ʃ ʒ tʃ dʒ c ɟ ɲ j k g ŋ x ɣ w q ʔ h y — no ɓ ɗ ʈ ɖ kp gb ᵐb. :77-84 segment_distance returns 99.0 for unknowns; :99-118 propose_page_sequence then falls back to -freq.get(g,0). Note the mirror-image asymmetry worth flagging: the SEGMENTATION inventory (io_put/lift.py) has ɓ ɗ ɖ kp gb but not β/ɸ, while the ORDERING table has β/ɸ but not ɓ ɗ ɖ kp gb.

_evidence:_ /Users/Seth/GIT/azt/backend/core/alphabet.py:44-118

### CONFIRMED: The 'wordlist' is an entire LIFT XML file parsed by the ordinary LiftXML class with tostrip=True; loadCAWL hardcodes one path and returns a LiftXML or an error string; templates.CAWL strips lexical-unit/citation forms.

io_put/cawl.py verified in full (path at :11, tostrip at :18, BadParseError→string at :19-22). io_put/lift.py:71-72 `if tostrip: return` before init_post_analang, verified. io_put/lift.py:1359-1364 strip_lxlc_forms verified. ADDITION the claim missed: loadCAWL's second handler (`except Exception as e: log.info(...)`) does NOT return — control falls to `return cawldb` with cawldb unbound, so a non-BadParseError parse failure raises UnboundLocalError rather than any message.

_evidence:_ /Users/Seth/GIT/azt/io_put/cawl.py:10-26; io_put/lift.py:69-73,1359-1364

### CONFIRMED: A wordlist entry carries multi-language glosses, POS literally 'Noun'/'Verb', a 4-digit zero-padded tag in sense/field[@type='SILCAWL'], and a DDP4 semantic-domain trait; images are NOT in the LIFT but resolved from tag number + underscored English gloss.

backend/core/lexicon.py:928-938 'This is reading values from template, which are Noun & Verb' and the remap to settings.nominalps/verbalps verified. '{:04}' at lexicon.py:922 and tasks/chooser.py:301. io_put/lift.py:1731,1747 field[@type='SILCAWL'] and :1736,1763 trait[@name='semantic-domain-ddp4'] — those two are the ONLY semantic-domain references in the whole repo (verified by grep), and both are copy-on-merge only. Image convention: io_put/lift.py:3163-3198 builds the directory regex from word_list_n + underscored English glosses; images/to_select_ReadMe.md:37-38 quote verified.

_evidence:_ /Users/Seth/GIT/azt/backend/core/lexicon.py:922,928-938; io_put/lift.py:1726-1770,3163-3198; images/to_select_ReadMe.md:34-38; grep semantic-domain → 2 hits

### CONFIRMED: 'word_list_field_name' is a half-built abstraction and CAWL is hardcoded in ~20 further places across the data/query and task/UI layers, including tasks/chooser.py getcawlmissing's literal range(1700).

I spot-checked every cited line and all resolve: io_put/lift.py:69-70, 135-146 (ValueError for non-SILCAWL), 558-559 get_senses_by_word_list_n, 2698 `elif self.ftype in ['location','SILCAWL']`, 1716-1777, 3163-3198, 3385-3389, 4088-4100 (ftype 'SILCAWL', kwarg literally 'cawlvalue'), 4541 `self.attrs['cawlfield']=['fvalue']`, 4558, 5428 `for i in range(1,1701)`. io_put/images_CAWL.py:18-21 and :81-90 (exactly two path segments) verified. tasks/chooser.py:297-303 getcawlmissing verified verbatim and is called unconditionally from whatsdone (:342), so every non-CAWL project reports all 1700 missing.

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:69-70,135-146,558-559,1716-1777,2698,3163-3198,3385-3389,4088-4100,4541,4558,5428; io_put/images_CAWL.py:18-21,78-90; tasks/chooser.py:297-303,342

### CONFIRMED: Word-by-word entry (addmorpheme) exists but is gated behind cawlmissing being empty; it collects an analang form plus one gloss per glosslang and writes ps=''. An entry with no gloss in the active glosslangs is skipped entirely.

backend/core/lexicon.py:736-741 else-branch verified; :872-905 addmorpheme loops `[self.analang]+self.program.db.glosslangs` and calls addentry(ps='',...). io_put/lift.py:333-381 addentry writes an empty <lexical-unit> and puts the form in <citation>. docs/TASKSCOLLECTION.md:15 'It is only present after the [CAWL] is done.' verified verbatim. Gloss skip verified at backend/core/lexicon.py:1380-1387. Note the combination with the format bug: the else-branch is unreachable for any non-CAWL project not because of the gate alone but because the if-branch raises before returning.

_evidence:_ /Users/Seth/GIT/azt/backend/core/lexicon.py:726-741,872-908,1380-1387; io_put/lift.py:333-381; docs/TASKSCOLLECTION.md:15

### CONFIRMED: Multiple analangs are modelled and keyed per-analang for profiles/polygraphs, but only one is active at a time, switching restarts the app, the picker only lists analangs already in the data, and the alphabet and sort-status stores are NOT keyed by analang.

io_put/lift.py:1374-1391 builds analangs by frequency; :1407-1446 find_plausible_analang picks one, settings winning. backend/core/profiles.py:176 and frontend/config/settings_ui.py:146 are per-lang. frontend/config/settings_ui.py:300-308 setanalang → self.program.restart(). frontend/ui_shell.py:3511-3512 `if len(self.program.db.analangs) <2: self.getanalangname(); return`. Culling at io_put/lift.py:1532-1536 (plus a further <1% warning at :1537-1540 the claim did not mention). settings/__init__.py:240-253 alphabet domain attributes are flat with no language dimension — verified verbatim; tests/test_status_dict.py:3-6 confirms the status shape is [cvt][ps][profile][check]. Project JSON path shape confirmed at settings/manager.py:61-63.

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:1374-1446,1528-1540; backend/core/profiles.py:176; frontend/config/settings_ui.py:146,300-308; frontend/ui_shell.py:3511-3531; settings/__init__.py:240-253; settings/manager.py:61-63; tests/test_status_dict.py:3-6

### CONFIRMED: The new-project dialog builds BCP-47 private-use dialect subtags (iso[-TERRITORY][-x-dialect]), so per-dialect tagging is already shipped.

frontend/ui_shell.py:2936-2945 button 'I'm working on a dialect of this language' and label 'give two to eight (2-8) characters to identify your dialect' with an 'x-' prefix label, verified. :3071-3078 update_code appends '-'+territory then '-x-'+variant.lower(). backend/langtags.py:69-91 validate_private verified. Caveat worth stating: the resulting tag is still passed through check_tag_validity → langcodes.tag_is_valid, so the base ISO code must be registry-valid regardless of the dialect subtag.

_evidence:_ /Users/Seth/GIT/azt/frontend/ui_shell.py:2932-2951,3071-3086,3145; backend/langtags.py:69-91

### CONFIRMED: Kent's real multi-dialect workflow is one LIFT per dialect joined by CAWL number, via a script-only, uncalled analyze_relationships().

io_put/lift.py:5414 analyze_relationships, :5428-5432 the `for i in range(1,1701)` join on sensesbyword_list_n, pairwise stats. Its only reference is the commented-out call at :5542. The lol-x-hisNNNNN / lse-x-his / lal-x-3886 dialect corpus is at :5525-5540 with filenames built as /home/kentr/.../WeSay/{d}/{d}.lift.

_evidence:_ /Users/Seth/GIT/azt/io_put/lift.py:5414-5462,5525-5545

### CONFIRMED: addCAWLentries does not type-check loadCAWL()'s return value, so a missing template becomes an AttributeError on a str; templates.CAWL does guard it.

backend/core/lexicon.py:914 `self.cawldb=loadCAWL()` then :921 `.get(...)` with no isinstance check; backend/core/templates.py:90-92 does guard (`if type(t) is str`). ADDITION the claim missed: two lines later, backend/core/lexicon.py:921-923 ends `.get('node')[0] #certain to be there` — an IndexError for any tag the template lacks, on top of the str case.

_evidence:_ /Users/Seth/GIT/azt/backend/core/lexicon.py:909-925; backend/core/templates.py:88-92

### CONFIRMED: The two 'CAWL' items in the Recording menu are label-only coupling; tasks/sound.py contains no CAWL reference.

frontend/ui_shell.py:313-316 labels verified. `grep -c -i cawl tasks/sound.py` → 0. showentryformstorecord (tasks/sound.py:168+) operates on program.slices and program.db.senses only.

_evidence:_ /Users/Seth/GIT/azt/frontend/ui_shell.py:313-316; tasks/sound.py:168-190; grep count 0

### CONFIRMED: planning/DEKEREKE_IO_PLAN.md already treats WordListTemplate/CAWL as the extension point but omits the three hardest seams (range(1700), word_list_field_name, the image-resolver ValueError).

planning/DEKEREKE_IO_PLAN.md:69-99 verified: the table names templates.py, io_put/cawl.py and ui_shell.py ~L3170/~L3276, and recommends `Dekereke(WordListTemplate)`. It cites io_put/lift.py:333 addentry but makes no mention of tasks/chooser.py:297-303, io_put/lift.py:70, or io_put/lift.py:139-145. It also omits the two crashers verified here (lift.py:678 cawln; the dobuttonkwargs format bug).

_evidence:_ /Users/Seth/GIT/azt/planning/DEKEREKE_IO_PLAN.md:65-100

### CONFIRMED: UNCERTAIN: the actual content of SILCAWL.lift could not be verified because the file is not on this machine.

Independently confirmed: /Users/Seth/GIT/lift_templates does not exist, and azt/lift_templates/ holds only SILCAWL_ReadMe.md, SILCAWL_update.py, __init__.py. The 1700 figure is sourced only from code (tasks/chooser.py:301, io_put/lift.py:5428) and docs (docs/TASKSCOLLECTION.md:11). Settling it requires cloning github.com/kent-rasmussen/lift_templates and counting distinct sense/field[@type='SILCAWL']/form/text values and their @lang gloss set.

_evidence:_ ls /Users/Seth/GIT/lift_templates → No such file or directory; ls /Users/Seth/GIT/azt/lift_templates/

## Missed
- THE HEADLINE ITEM IS BURIED AND MISLABELLED. The investigation ranked the cawln AttributeError as a '[high] latent' bug at the bottom of the second list. I actually reproduced it: loading a two-entry Fayu LIFT (lang='fau', English glosses, no CAWL fields) via lift.LiftXML(path, analang='fau') raises `AttributeError: 'Sense' object has no attribute 'cawln'` at io_put/lift.py:678 from init_post_analang line 87 — before any UI exists. backend/core/file_parser.py:29-35 catches it, shows 'There seems to be a (non-XML) problem loading your database', clears the default filename, and re-raises. On current main, A-Z+T cannot open a Papua LIFT file at all. Every downstream finding about buttons, tasks and CAWL gates is moot until this one line is fixed (`i.cawln` → `i.word_list_n`, two occurrences at :678 and :684, plus :4620-4621).
- THE β/ɸ GAP INVERTS THE SUMMARY'S CENTRAL REASSURANCE. The summary says the analytic core is language-general and 'Fayu's inventory (i u o ɛ a, β) is fully covered'. The bilabial fricatives β and ɸ are absent from the hardcoded segment inventory in io_put/lift.py:1795-1977 (which does carry ɓ ɗ ɖ kp gb — a West/Central African set). Since db.s is hypotheticals ∩ data (io_put/lift.py:1988-1993), an unlisted glyph is unclassified, survives into the profile string, and profiles.py:323-324 stamps the word 'Invalid'. I verified: 'βa'→'βV'→Invalid, 'kaβa'→'CVβV'→Invalid. The advertised runtime escape hatch, backend/core/profiles.py:231 addtoCVrxs, has zero callers. This is a one-line data fix (add β/ɸ to c['fvd']/c['f']) but it is a real limitation, not configuration, and it is the single most Fayu-specific blocker in the codebase.
- LOADING ANY DATABASE CAN TRIGGER A MULTI-HUNDRED-MB CLONE FROM A RELATIVE PATH. io_put/lift.py:3163-3165 does `rootimgdir='images/toselect/'` then `if not os.path.isdir(rootimgdir): from images.to_select_update import ensure_available; ensure_available()` — inside Sense.getglosses, i.e. per sense during load. The path is CWD-relative, and the images_CAWL spec (utilities/sister_repos.py:55-62) carries timeout=3600 and its own 'a few hundred MB' note. My first unstubbed load attempt hung past a 2-minute limit here. For a field machine on satellite internet in Jayapura this is a worse first-run experience than any of the analysed defaults.
- THE FORMAT BUG HAS NO SURVIVING CORRECT PATH IN THE SHIPPED TASK LIST. The investigation noted tasks/tasks.py:537 uses the correct {count}. It did not check that its class, WordCollectnParse, is commented out of tasks/chooser.py:177, while both classes that ARE offered — WordCollectionCitationwRecordings (→ backend/core/lexicon.py:731) and WordCollectnParsewRecordings (tasks/tasks.py:578) — carry the broken '{}'. There is no configuration under which a non-CAWL project gets a working primary button.
- NC/CG DEFAULTS ARE NOT THE PRENASAL BLOCKER; POLYGRAPH CONFIRMATION IS. I tested the four-cell matrix: with 'mb' confirmed as a digraph, 'mba'→CV under the DEFAULT NC='CC'; only an unconfirmed 'mb' yields CCV. So the recommendation implied by that finding (change NC per project) is the wrong lever — the lever is the polygraph candidate list and its confirmation dialog, which is exactly where the closed Vdg list and the en/fr-only LWC defaults bite. The two findings should be merged.
- loadCAWL HAS A SECOND, SILENT FAILURE MODE. io_put/cawl.py:19-25: the BadParseError handler returns a translated string, but the following `except Exception as e: log.info(...)` does NOT return — control reaches `return cawldb` with cawldb unbound → UnboundLocalError. Likewise backend/core/lexicon.py:921-923 ends `.get('node')[0] #certain to be there`, an IndexError for any absent tag. Both matter for a Dekereke/QWOM template that reuses this loader.
- 'iau' IS NOT A LANGUAGE CODE, AND THE GATE IS WIDER THAN REPORTED. Iau is ISO 639-3 'tmu' (tag_is_valid('tmu')=True; present in data/ethnologue_language_relationships.py as Lakes Plain > Tariku > Central); Fayu is 'fau'. The investigation treated 'iau' as Iau's code and concluded A-Z+T rejects Iau — it does not. What it DOES do, and the investigation missed, is filter db.analangs through tag_is_valid on every load (io_put/lift.py:1389): an existing FLEx export whose writing system is a non-registry tag such as 'iau' or 'iau_tmu' silently loses that analang and can fall through to 'I can't find a plausible analang' (:1444-1446). That is a migration hazard for Seth's existing data, not just a new-project inconvenience.
- REPO REQUIRES PYTHON 3.12+. backend/langtags.py:289 uses a backslash inside an f-string expression, a SyntaxError on 3.11. Worth knowing before anyone tries to run this on a field laptop's system Python.