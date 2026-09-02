# Adversarial verification pass 2

## Bottom line

The two investigations are substantially correct and unusually well-grounded — I could not refute any load-bearing conclusion. Every high-value structural claim survived: no plugin/discovery mechanism exists (grep-verified); addentry really does self.write() per entry at lift.py:333/377 and has exactly one caller, so the draft plan's "populate via addentry" is genuinely refuted; the CAWL-shaped load is the right template; test_import_smoke.py really does rglob-discover so plan §5 is wrong; plan §7's "XSLT + lxml" really does contradict its own §3 and the repo's deliberate lxml-off stance; the encoding tests reproduce exactly; and the social finding is stronger than stated — issue #165's body explicitly names "supporting Dekereke XML as a format for wordlists and export", so Kent has literally declined this request, and the community/PR data (165 PRs, all Kent or bots; health 42; no CONTRIBUTING) is confirmed. What fails is precision, in a consistent direction: numbers and line ranges are inflated or drifted (168 PRs → 165; "16 collab tests" → 38; nine _Pitch columns → ten; Menus 194-420 → 194-599; refusal constants 1105-1125 → 1013-1018; collab menu 400-462 → 364-406). Four substantive overstatements matter for planning: (1) "exactly one changed line" is false and contradicts the same report's own hunk list — templates.CAWL also appears at ui_shell.py:3285, and passing the source path requires added attributes; (2) "fill_db_images is SAFE" hides an AttributeError on self.imgdir if init_post_analang is skipped and a ZeroDivisionError at lift.py:2357 when every record is skipped for empty Phonetic — the exact case plan §2 fact 7 mandates; (3) the collab no-clobber invariant has an explicit exception (merged_identical advances base_sha, collab.py:275-282) and there IS daemon-side BUSY locking (243-262); (4) ADRs 0001 and 0003 are both "proposed", AI-drafted, and 0001 is explicitly "not yet reviewed/owned by the maintainer" — citing them upstream as settled contracts would misfire.

### OVERSTATED: A-Z+T has NO plugin, entry-point, or dynamic-discovery mechanism; the only importlib uses are settings/__init__.py:289 and utilities/py_modules.py:547, plus tests.

Conclusion is right (no discovery mechanism exists) but the enumeration is incomplete: it misses utilities/file.py:73 `from importlib import reload as modulereload`. I grepped for `modulereload` across all *.py — the only hit is its own definition line, i.e. it is an unused re-export, not a loader. Also confirmed: `grep -rni 'plugin|addon'` over *.py returns zero hits; root has no setup.py and no pyproject.toml (full `ls -a` verified).

_evidence:_ utilities/file.py:73; grep -rn 'modulereload' --include='*.py' → 1 hit (the def site only); main.py:73, settings/__init__.py:125,289-290, utilities/py_modules.py:547,557, tests/test_import_smoke.py:16,87, tests/test_backend_logic.py:15,22

### CONFIRMED: The repo's optional-feature precedent is (a) module-level try-import + a `program` flag, (b) function-local try-import that logs and returns.

Verbatim correct. io_put/sound.py:18-25 `try: import pyaudio / except Exception as _e: pyaudio=None` (+ same for numpy); main.py:53-67 sets `program['nosound']=not sound.PYAUDIO_OK` (59) / `program['nosound']=True` (64); consumers at frontend/sort_buttons.py:638, tasks/chooser.py:525, tasks/transcribe_glyph.py:309; CLAUDE.md:175 documents it. io_put/xlp.py:90-95 is the function-local form.

_evidence:_ io_put/sound.py:18-25; main.py:53-67; CLAUDE.md:175; io_put/xlp.py:90-95

### CONFIRMED: tests/test_import_smoke.py requires NO edit; the draft plan §5 is wrong. Only the exclusion lists (lines 27-45) are hand-maintained.

Confirmed with one addition: OPTIONAL_DEPS (lines 49-56) is a third hand-maintained list, not covered by 'lines 27-45'. It only matters if the new module imports a third-party package — a stdlib-only io_put/dekereke.py is auto-discovered by `_discover()` (58-79) and needs nothing. Plan §5's sentence 'Add the new module to the import smoke test list in tests/test_import_smoke.py' is verifiably wrong: there is no such list.

_evidence:_ tests/test_import_smoke.py:24 PACKAGES, 27-45 EXCLUDE_*/EXPECTED_NOT_IMPORTABLE, 49-56 OPTIONAL_DEPS, 58-79 _discover(), 82 parametrize; planning/DEKEREKE_IO_PLAN.md §5

### CONFIRMED: `LiftXML.addentry` (lift.py:333) calls `self.write()` (lift.py:377) on every entry, so a 944-record import would serialize the whole LIFT 944 times; only caller is backend/core/lexicon.py:902.

Exact. `def addentry(self, showurl=False, **kwargs)` at io_put/lift.py:333; `self.write()` at 377, followed by `self.getguids()` / `self.getsenseids()` (378-379) — so the cost is worse than stated: each call also re-walks the tree twice to rebuild the guid and senseid sets. write() at 1240-1264 does `xmlfns.indent(self.nodes)` over the whole tree then `tree.write(tmp, encoding='UTF-8')`; the comment at 1247-1252 says a one-line edit rewrites the whole file, 'easily 16 MB'. Sole caller confirmed at backend/core/lexicon.py:902. Draft plan §3 explicitly proposes `to_lift(...)` 'populated via LiftXML.addentry(...)' — that proposal is refuted.

_evidence:_ io_put/lift.py:333,377,378-379,1240-1264; backend/core/lexicon.py:902; planning/DEKEREKE_IO_PLAN.md §3

### CONFIRMED: The cheapest correct architecture is build a finished .lift then `lift.LiftXML(path, tostrip=True)`, mirroring io_put/cawl.py:18; zero edits to io_put/lift.py.

Exact. io_put/cawl.py is 26 lines; line 18 is `cawldb=lift.LiftXML(str(stockCAWL),tostrip=True)`; it returns either a LiftXML or an error string, and templates.py:88-93 branches on `type(t) is str`. `tostrip=True` returns at lift.py:72 before `init_post_analang`, which templates.py:82 then calls after verify_writeable retargets the filename (templates.py:60).

_evidence:_ io_put/cawl.py:10-26; io_put/lift.py:57-73; backend/core/templates.py:60,82,88-93

### OVERSTATED: Reusing the entire new-project pipeline costs EXACTLY ONE changed line, because the template class is hard-coded at one site (ui_shell.py:3170).

Three problems. (1) It is not one site: `templates.CAWL(...)` also appears at frontend/ui_shell.py:3285 inside `makeCAWLdemo` — irrelevant to the New path but it falsifies 'hard-coded at one site'. (2) One changed line is not sufficient: a Dekereke template needs the chosen source path, so 3170 must become something like `self.template_class(self.program,analang=self.code,**self.template_kwargs)`, and both attributes need defaults added (at minimum one ADDED line in LiftChooser). (3) The finding contradicts the later file-list finding in the same set, which lists hunk B (line 3170) PLUS an `elif`, an optionlist row, and a ~10-line `importdekereke()`. The defensible claim is: the body of `_analang_code_complete` (3168-3186) is source-agnostic and needs only its constructor call parameterized.

_evidence:_ frontend/ui_shell.py:3170, 3285; class LiftChooser spans 2889-3452 (startnewfile 2982, _analang_code_complete 3157, store_analang 3269, setfilename 3356, __init__ 3410)

### OVERSTATED: Reusing the pipeline is SAFE for a non-CAWL database because `fill_db_images()` no-ops per sense (lift.py:2341 → 3398 `if not self.word_list_n: return False`).

The per-sense no-op is real and exactly as cited (fill_db_images at 2341-2357; get_word_list_n 3385-3389 sets word_list_n=None when 'SILCAWL' is absent from self.fields; backfill_illustration 3392 begins `if not self.word_list_n: return False`; Sense.__init__ calls get_word_list_n at 3758). But 'SAFE' hides two real failure modes the claim does not mention: (a) fill_db_images dereferences `self.imgdir` at line 2344 (`log.info('Writing to {}'.format(self.imgdir))`), which exists only because init_post_analang→get_imgdir ran (lift.py:128,189-192) — a Dekereke template that skips init_post_analang AttributeErrors before reaching any sense; (b) line 2357 divides by `len(self.senses)`, so a Dekereke file whose every record is skipped (empty Phonetic — plan §2 fact 7) yields ZeroDivisionError, not an empty project.

_evidence:_ io_put/lift.py:2341-2357 (esp. 2344 self.imgdir, 2357 len(self.senses)), 128, 189-192, 3385-3389, 3392-3398, 3758

### OVERSTATED: The UI hook is two tiny hunks in LiftChooser: optionlist at ui_shell.py:3421-3432 and the if/elif chain in setfilename at 3356-3375. The Menus machinery (194-420) is not where project creation lives.

The LiftChooser facts are exact — optionlist is built as (key,label) tuples at 3421-3432 ('New','Team','Clone', recents, 'Other','Demo') and setfilename dispatches on the key string at 3356-3375. But `class Menus` runs 194-599, not 194-420 (the next class, StatusFrame, starts at 600). The collab menu wiring the collaboration findings cite as '400-462' is actually `def collaboration` at 364-406.

_evidence:_ frontend/ui_shell.py:3356-3375, 3421-3432; `grep -n '^class '` → Menus 194, StatusFrame 600; collaboration() 364-406

### CONFIRMED: backend/core/templates.py is 100 lines; CAWL is lines 84-99 (16 lines); verify_code (19-41) and verify_writeable (42-61) are reusable as-is.

Exact — `wc -l` gives 100; WordListTemplate at 12; CAWL at 84-99 ending the file. Note for implementation: CAWL sets `self.db` BEFORE calling `super().__init__`, and calls `self.db.strip_lxlc_forms()` afterwards (97) — a Dekereke sibling must follow the first and must NOT do the second. Extra kwargs are harmless: verify_writeable only reads `kwargs.get('demo')` (44).

_evidence:_ backend/core/templates.py:12,19-41,42-61,66-82,84-99; wc -l = 100

### CONFIRMED: Kent has already been asked for exactly this and declined the general case in issue #165 (closed 2026-04-01).

Stronger than stated. The issue BODY, which the finding did not quote, names Dekereke explicitly: 'Bundling other comparative wordlists like QWOM (Quickstart Wordlist of Melanesia) and supporting Dekereke XML as a format for wordlists and export would also be useful to many people.' Opened by rulingAnts 2026-03-18T22:58:38Z, closed 2026-04-01T15:17:43Z. Kent's 2026-03-23T19:17:42Z comment matches the quoted text verbatim, including the typos 'LIFt' and 'currrently'.

_evidence:_ gh api repos/kent-rasmussen/azt/issues/165 (body, state, created_at, closed_at) and .../issues/165/comments

### OVERSTATED: Kent's 'designed to allow the addition of wordlists other than SILCAWL' is aspirational; code hard-codes SILCAWL and raises otherwise. lift_templates/ contains only SILCAWL_update.py and its README.

The code claim is CONFIRMED — io_put/lift.py:70 `self.word_list_field_name='SILCAWL' #make this configurable`; get_img_resolver at 135 raises ValueError for any other value (the branch is at 139, the raise at 143-145, not '138-145'). The directory claim is wrong in two ways: lift_templates/ also contains __init__.py, and it contains NO SILCAWL/ subdirectory at all — cawl.py:11-14 expects 'lift_templates/SILCAWL/SILCAWL.lift' and calls `SILCAWL_update.ensure_available()` to fetch it on demand. That is worth knowing: the CAWL template is a runtime download, so a Dekereke source needs no bundled data by symmetry.

_evidence:_ io_put/lift.py:70,135-145; ls lift_templates/ → SILCAWL_ReadMe.md, SILCAWL_update.py, __init__.py; io_put/cawl.py:11-14

### OVERSTATED: All 168 PRs are Kent's own branches or bots (kent-rasmussen 116, gitlocalize 35, github-actions 12, dependabot 2); no human outside contributor has ever landed a PR.

The composition is exactly right but the total is wrong: the repo has 165 PRs, not 168. Verified two ways — the Link header for per_page=1 gives rel="last" page=165, and the two histogram pages sum to 51+65 kent-rasmussen = 116, plus 35 gitlocalize-app[bot], 12 github-actions[bot], 2 dependabot[bot] = 165. Both dependabot PRs confirmed `merged:false, state:closed` (#166 torch 2.12.0+cpu, #167 torch 2.12.1+cpu). Contributors API confirms kent-rasmussen 11017, mt-gitlocalize 52, gitlocalize-app[bot] 13, crowdin-bot 9.

_evidence:_ gh api 'repos/kent-rasmussen/azt/pulls?state=all&per_page=1' -i (Link: page=165 rel=last); pulls pages 1-2 histograms; gh api repos/.../pulls/166,167; gh api repos/.../contributors

### CONFIRMED: No CONTRIBUTING.md, no PR template, no issue template, no code of conduct, no test CI; only two Crowdin workflows.

Exact. `gh api repos/kent-rasmussen/azt/community/profile` → health_percentage 42, files.contributing null, files.code_of_conduct null, files.pull_request_template null, files.issue_template null (license gpl-3.0, readme docs/README.md). .github/ contains only workflows/ with download-translations.yml and upload-strings.yml. Note the repo description returned by the same call — 'sorting a lexical database on consonants, vowels, and tone' — independently corroborates the tone argument.

_evidence:_ gh api repos/kent-rasmussen/azt/community/profile; ls -la .github/workflows

### CONFIRMED: azt.pot has 15738 lines and 9181 `#:` reference lines carrying Kent's absolute paths; 1935 point at ui_shell.py; POT-Creation-Date 2026-07-27. Contributors must add _() strings but never regenerate the .pot/.po/.mo.

Every number verified: wc -l 15738, grep -c '^#:' 9181, grep -c 'ui_shell.py' 1935, header line 11 POT-Creation-Date 2026-07-27 11:50+0100. Line 20 is `#: /home/kentr/bin/AZT/azt/frontend/ui_shell.py:3781`, and lines 21-24 add four more machine-specific refs of the form `/home/kentr/bin/AZT/azt/file:/media/kentr/88C5-0968/azt_shallow*.git/...` — i.e. the .pot leaks not just his home dir but his USB-stick bare repos, which is even stronger support for 'do not regenerate'. Compiled .mo files are committed for ar_SA, es_ES, fr_FR, ln_CD, zh_CN.

_evidence:_ translations/azt.pot lines 11,20-24; wc/grep counts; ls translations/*/LC_MESSAGES/

### CONFIRMED: verify_strings.py cannot be run by a contributor, hard-codes /home/kentr/bin/raspy/azt/, names pre-refactor filenames, and contradicts translations/README.md on `.format()`.

Exact. verify_strings.py:15 `filepath = os.path.join('/home/kentr/bin/raspy/azt/', filename)`; files_to_check at 4-10 lists main.py, ui_tkinter.py, lift.py, alphabet_chart.py, parser.py — 'ui_tkinter.py' does not exist anywhere in the tree, and lift.py/parser.py now live in io_put/ and backend/. The `.format(` check is at lines 41-46 (the claim said 44-49). translations/README.md:25 states there is no difference between `_("").format()` and `_("".format())` and documents .format() usage as normal, contradicting the checker.

_evidence:_ verify_strings.py:4-10,15,41-46; translations/README.md:25,28,33,39

### CONFIRMED: In Python `ET.parse(path)` reads all three Dekereke encodings with no sniffing; only a text-mode handle fails. Tested against SampleLang_full.xml.

Reproduced all four cases myself on /Users/Seth/dekereke-pa-data-source/sample-data/SampleLang_full.xml (first bytes b'\xff\xfe<\x00?\x00x\x00m\x00l\x00', `file` reports UTF-16LE with CRLF): ET.parse(path) → 10 data_form records; ET.parse(io.BytesIO(raw)) → 10; ET.fromstring(raw.decode('utf-16')) → 10; ET.parse(open(path,encoding='utf-16')) → ParseError 'encoding specified in XML declaration is incorrect: line 1, column 30'. SampleLang_minimal.xml is UTF-8 with `<?xml version="1.0" encoding="utf-8"?>` and CRLF.

_evidence:_ Executed python3 against sample-data/SampleLang_full.xml and SampleLang_minimal.xml; `file` output

### CONFIRMED: lxml/XSLT (plan §7) is the wrong dependency choice and contradicts plan §3 and repo convention.

Both halves verified. Plan §7 says 'the target here is XSLT + a thin lxml driver (§3)' while §3 describes a pure-Python `DekerekeXML` / `column_guesses` / `to_lift` converter and never mentions XSLT — a direct internal contradiction. Repo side: io_put/lift.py:8-12 has the lxml import commented out, line 13-15 logs 'using xml.etree to parse XML' and sets `lxml=False`; io_put/xlp.py:90-95 imports lxml lazily and returns on ImportError; requirements.txt:21 lists lxml but tests/test_import_smoke.py:49-56 puts it in OPTIONAL_DEPS so its absence is a skip; utilities/xmletfns.py:3 wraps stdlib ElementTree and is the house API.

_evidence:_ planning/DEKEREKE_IO_PLAN.md §3,§7; io_put/lift.py:8-15; io_put/xlp.py:90-95; requirements.txt:21; tests/test_import_smoke.py:53; utilities/xmletfns.py:3

### OVERSTATED: SampleLang_full.xml: root <phon_data>, 10 <data_form>, 42 distinct child tags, nine `_Pitch` twins, qvp_acoustic_data_ the only child with children, Reference=0012 has Phonetic text None; DkUserSettings carries sound_file_path and column_to_sound_file_suffix_mappings.

All structural facts reproduced exactly (root phon_data, 10 records, 42 distinct tags, only qvp_acoustic_data_ has a child — one qvp_acoustic_data_set, record 0012 Phonetic text is None). One count is wrong: there are TEN `_Pitch` columns, not nine — the list omits `IMP-re_Pitch`, which is the interesting one because it proves a `_Pitch` twin can hang off a column name containing a hyphen. DkUserSettings confirmed verbatim: UTF-16LE, `<sound_file_path>C:\SampleLang\audio</sound_file_path>`, and two tab-separated mappings `Phonetic\t-phon`, `Speaker2\t-sp2` — note `Speaker2` is NOT among the 42 columns of the data file, so a suffix mapping can name a column that does not exist.

_evidence:_ Executed ET parse of sample-data/SampleLang_full.xml (42 tags incl. IMP-re, IMP-re_Pitch, Orth.practice); decoded sample-data/SampleLang_full-DkUserSettings.xml

### CONFIRMED: The column-mapping heuristic is a fact table in AutoMapper.cs:44-62 (125 lines total), first-match-wins comment at line 40.

All ten role→synonym lists match verbatim (Phonetic/Fonetik/IPA; Reference/Ref/No/Nomor; Pitch/Tone/Nada/Surface_Melody; Phonemic/Fonemik; Gloss/Arti/EnglishGloss; IndonesianGloss/Gloss2/ArtiIndonesia/NationalGloss; Category/POS/PartOfSpeech/Kategori/KelasKata; Orthography/Tulisan/Ejaan; SoundFile/Audio/Sound/Rekaman; Notes/Note/Catatan). File is 125 lines. Minor line drift: the Synonyms array runs 42-64 and the ordering comment is at 35-40, which states the rule twice — fields earlier claim columns first, AND within a field the earlier synonym wins.

_evidence:_ /Users/Seth/dekereke-pa-data-source/src/DekerekeToPa/AutoMapper.cs:35-64; wc -l 125

### OVERSTATED: The strongest technical argument for the PR is TONE, and it is absent from the draft plan.

The A-Z+T side is CONFIRMED: io_put/lift.py:51-56 language_codes includes 'tonelangs':langtags.tone_code and 'machine':langtags.machine_transcription_code; tonelangname() at 147-155 builds `<lang>-x-tone` (+machine); the GitHub repo description says 'sorting a lexical database on consonants, vowels, and tone'. But 'absent from the draft plan' is too strong — plan §2 fact 6 does flag the `_Pitch` twin columns. What is genuinely absent is tone in the §3 role list (citation form, gloss(es), grammatical category, sound file, reference/id, notes — no tone role), which is the sharper criticism: the plan sees the tone columns and then drops them on the floor at mapping time.

_evidence:_ io_put/lift.py:51-56,147-155; planning/DEKEREKE_IO_PLAN.md §2 fact 6, §3 role list; gh community/profile description

### CONFIRMED: ElementTree writes no XML declaration for encoding='UTF-8'; CRLF preservation (plan §2 fact 8) is neither achievable nor necessary; empty elements round-trip as <kosong />.

Reproduced: `ET.ElementTree(root).write(buf, encoding='UTF-8')` → b'<phon_data><data_form><kosong /></data_form></phon_data>' — no declaration, self-closing preserved; encoding='utf-16' emits BOM + declaration. io_put/lift.py:1264 uses `tree.write(tmp, encoding="UTF-8")`, so A-Z+T's own LIFT output has no declaration either. Real Dekereke files do carry one (SampleLang_minimal.xml line 1).

_evidence:_ Executed ET write test; io_put/lift.py:1264; sample-data/SampleLang_minimal.xml:1

### CONFIRMED: Ship no sample data files with the PR (sample-data/README.md says tests generate their own fixtures).

README text confirmed at lines 31-32. Independently supported by Kent's own issue-#165 objection about wordlist licensing/attribution, and by the fact that A-Z+T does not bundle SILCAWL either (cawl.py:11-14 downloads it).

_evidence:_ /Users/Seth/dekereke-pa-data-source/sample-data/README.md:31-32; io_put/cawl.py:11-14

### CONFIRMED: Commit convention: short lowercase fragments, no conventional-commits, no merge commits, no tags; local clone is shallow (51 commits back to 2026-07-21).

Verified: .git/shallow exists, `git log --oneline | wc -l` = 51, `git log --merges` = 0, `git tag` = 0, subjects are 'image fix', 'boot hang fix', 'fix NA again...', 'font issues resolved?' etc. Two caveats worth carrying: (a) the oldest reachable commit's own subject is 'Merge branch main into testing' (2026-07-21) — --merges reports 0 only because the graft point hides its parents, so 'no merge commits' characterizes nothing; (b) HEAD is Seth's own local commit 2872868 'Plan Dekereke XML import/export for A-Z+T' (2026-09-02) adding planning/DEKEREKE_IO_PLAN.md and planning/DEKEREKE_CLOUD_PROMPT.md — the fork already diverges from upstream.

_evidence:_ ls -la .git/shallow; git log --oneline|wc -l; git log --merges; git tag; git log -1 --format='%an %ad %s'; git show --stat HEAD

### OVERSTATED: Current sync transport is git driven by an out-of-process daemon in a separate repo; azt uses 16 RPC calls via azt_collab_client.

The architecture claim is CONFIRMED verbatim from the collab.py:1-34 docstring ('This module is the ONLY azt code that talks to azt_collab_client... azt itself must never import azt_collabd') and main.py:316-329 repocheck. The RPC count is off: there are 15 DISTINCT client methods (submit_file, project_status, lan_peer_sync, get_contributor, set_contributor, commit_project, sync_project, sync_nudge, configure, open_project, list_projects, register_project, open_server_ui, pick_project, restart_server), invoked from ~28 call sites — 'the complete RPC surface is 16 calls' conflates methods with sites and lands on neither number.

_evidence:_ backend/core/collab.py:1-34 and `grep -n '_client\.'` (28 sites, 15 distinct methods); main.py:316-329

### CONFIRMED: WAN sync is GitHub-only (non-GitHub internet remotes refused outright); LAN is peer-to-peer needing no internet.

Refusal is at backend/core/collab.py:1278-1284 (claim said 1279-1285, one off): `if _is_internet_url(url) and 'github.com' not in url` → 'collaboration currently supports GitHub only, so it stays on the legacy path'. Mercurial-only projects are refused immediately above at 1271-1277. WORD_COLLECTION.md:10 confirms the two-channel field story.

_evidence:_ backend/core/collab.py:1271-1284; docs/ws/WORD_COLLECTION.md:10

### OVERSTATED: There is NO Chorus and NO Harmony: harmony_sync.py is a dead orphan; Chorus appears ONLY as damage detection.

Harmony is CONFIRMED dead: harmony_sync.py:4 `from harmony_client import HarmonyClient` (module absent), class AZTHarmonyBridge at 8 and a fictional AZTMainWindow at 77, and tests/test_import_smoke.py:41 skips it as a WIP orphan. 'Chorus ONLY as damage detection' is wrong: besides vcs.py:745-757 (.ChorusRescuedFile) and 810-814 (.ChorusNotes/.WeSayConfig* ignores), frontend/vcs_ui.py:51 puts Chorus in a user-facing string ('Mercurial is used by Chorus and ...'). Also note vcs.py:756 `if self.program.me: exit()` — the Chorus check hard-exits on Kent's own machine.

_evidence:_ harmony_sync.py:4,8,77; tests/test_import_smoke.py:41; backend/core/vcs.py:745-757,810-814; frontend/vcs_ui.py:51

### OVERSTATED: The collab layer is inert in Seth's checkout; collab.AVAILABLE is False and all 16+ collab tests skip.

Inertness CONFIRMED: `readlink azt_collab_client.old` → /home/kentr/bin/AZT/azt-collab/azt_collab_client, `test -e` fails; neither ../azt-collab nor ../azt_collab exists; _ensure_client_importable (58-97) therefore returns False and AVAILABLE=False (102/106); tests/test_collab_session.py:28-32 skipif matches verbatim. The test count is wrong: `grep -c '^def test_'` gives 38, not 16. The same 38 vs '16 units' error recurs in the 'crown jewels' finding.

_evidence:_ readlink/test -e on azt_collab_client.old; backend/core/collab.py:58-106; tests/test_collab_session.py:28-32; grep -c '^def test_' = 38

### CONFIRMED: The unit of collaboration is the whole LIFT file per save; no per-entry channel, no locking.

Confirmed. io_put/lift.py:1284-1330 is the single interception point (`submit=getattr(self,'collab_submit',None)`; on 'ok' it returns without os.replace); collab.py:264-270 `submit()` sends `rel=os.path.basename(filename)` + staged path + base_sha; docs/CHANGELOG.md:952 'costs the same for 15 changed words as for 1500'. One correction to 'no locking': there IS daemon-side locking that azt observes — collab.py:243-262 retries a BUSY result up to BUSY_RETRIES ('Save hit a held project lock (BUSY)'). The lock is the daemon's project lock, not per-entry checkout, so the conclusion stands but 'no locking of any kind' is false.

_evidence:_ io_put/lift.py:1284-1330; backend/core/collab.py:243-270; docs/CHANGELOG.md:952

### OVERSTATED: azt never merges; the base deliberately does NOT advance after a merge — pinned by test_submit_merged_keeps_base_and_flags_stale.

There is an exception the finding omits, and it is in the very block quoted. collab.py:275-282: when the daemon reports MERGED_WITH_LOCAL with param `merged_identical` true (trivial merge, daemon 0.54.73+), azt DOES advance — `self.base_sha = result.head_sha or self.base_sha`, clears degraded, records the stat, returns 'ok'. The no-advance invariant at 283-300 applies only to non-identical merges. The regression test exists as named at tests/test_collab_session.py:93.

_evidence:_ backend/core/collab.py:275-300; tests/test_collab_session.py:93

### CONFIRMED: Legacy vcs.py conflict handling is crude and partly dead (commit_would_conflict is a bare pass; '=======' → ErrorNotice; reset --hard; mergetool only reachable when program.me; unreachable code after `return r` at 948; remotes keyed Thing1..Thing19).

All verified, with two line corrections: `commit_would_conflict(self): pass` is at 102-106 as claimed; the '=======' ErrorNotice is at 120-123 (claim said 118-120); mergetool is defined at 820-821 and its only call site (451) sits inside `if self.program.me and (iwascalledby in ['pull'] ...)` at 443 — the program.me gate is CONFIRMED; `return r` at 948 with ~20 dead lines after it CONFIRMED; `for key in ['Thing'+str(i) for i in range(1,20)]` at 611 CONFIRMED.

_evidence:_ backend/core/vcs.py:102-106,120-123,243-247,443-453,611,820-821,948-960; main.py:1161,1169 set program.me

### CONFIRMED: There is NO concept of assigning work to a person, no roles, no permissions, and no HTTP/socket surface anywhere.

Verified independently. `grep -rniE '\brole\b|\bacl\b|permission'` over backend/, settings/, main.py → zero hits. Every 'assign' hit is slice packing (analysis.py:812,855,902-972) or group membership (categories.py:3) or MRO commentary (report_mixins.py:10) — never a person. `grep -rniE 'flask|http\.server|socketserver|websocket|fastapi|uvicorn|qrcode'` over all *.py → zero hits, and none of those appear in requirements.txt. `import socket` appears nowhere in the tree.

_evidence:_ grep results across backend/, frontend/, tasks/, settings/, main.py, requirements.txt

### CONFIRMED: The only person-identity is one free-text contributor name per machine, seeded from git user.name; two machines sharing a name are indistinguishable.

collab.py:1314-1322 seeds exactly as described (`if not _client.get_contributor(): ... _client.set_contributor(name)` from repo then ~/.gitconfig user.name). The 'known limit' docstring is real and its warning is live code: collab.py:481-483 logs 'Self-authored suppression: %s commit(s), all under our own name %r. If another machine also uses that name, its work is being adopted silently here.' Attribution string at collab.py:505-506 `_('{count} change(s) from {who}')`. Legacy fallback confirmed at vcs.py:588-590: `'-'.join([self.program.name,_user,self.program.hostname])` via getpass.getuser(), plus a synthesized email at 596-597.

_evidence:_ backend/core/collab.py:455-508,1314-1322; backend/core/vcs.py:574-598

### CONFIRMED: settings/contributors.py is a 7-line append-only credit roster printed on the alphabet-chart PDF, not user identity; stored project-wide.

Exact. settings/contributors.py is 7 lines (a leading blank plus ContributorsConfig(ConfigManager) calling super().__init__('contributors',...) and self.load()). Consumers: frontend/alphabet_comparison.py:188-225 `class ContributorsManager(ui.Window)` titled _('People Involved') with the label _('Names cannot be removed once added.') at 225, opened from open_contributors at 480-484; backend/core/alphabet.py:1168-1183 passes contributors_list into the comparison chart. settings/manager.py:61-63 confirms 'contributors' is NOT in the per-user/per-host domain list, so it lands in `<base>.contributors.json` and is shared/merged.

_evidence:_ settings/contributors.py (7 lines); frontend/alphabet_comparison.py:188-225,480-484; backend/core/alphabet.py:1168-1183; settings/manager.py:61-63

### CONFIRMED: A per-device settings-scoping convention exists (audio/project/ui/preproject are per-user-per-host) and the collab opt-in lives in that per-machine domain.

settings/manager.py:61-63 verbatim: `if self.domain in ['audio','project','ui','preproject']: return self.base_path.with_suffix(f'.{self.user}.{self.hostname}.{self.domain}.json')` else `f'.{self.domain}.json'`. The collab flag is read at collab.py:1137 `mgr.project.get('collab', False)` and written at 1325-1326 `mgr.project.set('collab', True)` / `set('collab_langcode', langcode)` — i.e. the 'project' domain, which IS per-user-per-host, so the observation that opting in is per-machine is correct and consequential. Legacy analogue confirmed at settings/__init__.py:345-348.

_evidence:_ settings/manager.py:60-63; backend/core/collab.py:1137,1325-1326; settings/__init__.py:344-348

### CONFIRMED: The offline-first field story is real and field-validated, but the devices run separate Android apps not in this repo.

docs/ws/WORD_COLLECTION.md:6-10,21 confirmed verbatim, including the link to the wiki Apps page for A-Z+T Collab and A-Z+T Recorder. docs/CHANGELOG.md:1565 confirms the 2026-07-11 desktop↔phone LAN drill list. Degrade-never-lose contract D9 confirmed at collab.py:1124-1125 ('a field tool must never lose the ability to save') and in _decline's design at 1003-1030.

_evidence:_ docs/ws/WORD_COLLECTION.md:6-10,21; docs/CHANGELOG.md:1565; backend/core/collab.py:1003-1030,1119-1125

### CONFIRMED: docs/NEXT_GENERATION.md is the researcher-panel-with-assignments design Seth wants, written by Kent and entirely unimplemented (~40 lines).

Text confirmed verbatim, including 'a word/card should be in only one person's hand at a time', 'a group can be assigned to multiple clients at a time', and the QR-code paragraph. It is ~35 lines. Two things the finding does not say that matter: the doc specifies a Raspberry Pi server on 5V for power cuts and a JavaScript/React client — i.e. Kent's own sketch is explicitly NOT a tkinter feature — and it frames the goal as the 'multiple and contradictory input' he called impossible in his book chapter. Unimplemented status is corroborated by the zero-hit greps for server libraries and assignment state.

_evidence:_ docs/NEXT_GENERATION.md (full read); grep for flask|http.server|websocket|qrcode → zero

### OVERSTATED: The reusable crown jewels are the write seam, the base/staleness state machine, and the in-place reload path; 16 units in tests/test_collab_session.py.

The seams are real and where claimed (io_put/lift.py:1284-1330 single interception; main.py:351 collab_poll, 399 collab_offer_reload, 802 reload_database with the 'DESTROY NOTHING' docstring; collab.py:510 adopt_reloaded_db). Two corrections: (a) the hook is installed at TWO sites, not one — collab.py:1233,1237 in attach() AND collab.py:520-521 inside the reload path, so anything reusing the seam must reinstall it after a db swap; (b) the test count is 38, not 16.

_evidence:_ io_put/lift.py:1284-1330,1342; main.py:351,399,802; backend/core/collab.py:510,520-521,1233,1237; grep -c '^def test_' tests/test_collab_session.py = 38

### OVERSTATED: ADR 0003 is the durable per-item carrier for assignment results; a standing ADR (0001) forbids persisting the slice index.

Neither ADR is standing. docs/adr/0003-...md line 3: 'Status: proposed', author line: 'drafted by Claude (AI agent) with Kent'. docs/adr/0001-...md line 3: 'Status: proposed (provisional)', line 5: 'Author: drafted by Claude (AI agent), not yet reviewed/owned by the maintainer', and line 7 warns its own terminology 'is not yet settled'. So 'a standing ADR forbids persisting it' overstates a provisional, AI-drafted, maintainer-unreviewed proposal — which is a materially different footing to cite in an upstream PR. The technical content is quoted accurately (two values per item; `done` derived; slice index session-local; MAX_SLICE=50 at backend/core/analysis.py:772, tunable via the 'syllable_max_slice' setting).

_evidence:_ docs/adr/0003-sort-status-two-values-per-item.md:3,8,34-58; docs/adr/0001-syllable-slice-index-ephemeral.md:3,5,7,32,46; backend/core/analysis.py:772,903-937

### OVERSTATED: The per-project opt-in / visible-refusal pattern is the template Kent expects; six named refusal reasons at collab.py:1105-1125; menu wiring at ui_shell.py:400-462.

The pattern is real and the Kent quote is verbatim, but both line ranges are wrong. The six constants are at collab.py:1013-1018 (NO_SETTINGS='settings-unreadable', NO_LANGCODE, NO_CLIENT, NO_SERVER, WRONG_TREE, NO_HOOK), `_decline` is defined at 1030, the Kent 2026-07-31 quote is in the comment at 1003, and the _decline call sites are 1139/1156/1166/1185/1209/1240 — collab.py:1105-1125 is the tail of restart_connection plus the head of attach(). The menu wiring is `def collaboration` at frontend/ui_shell.py:364-406, not 400-462.

_evidence:_ backend/core/collab.py:1003,1013-1018,1030,1139,1156,1166,1185,1209,1240; frontend/ui_shell.py:364-406

## Missed
- The CAWL template is NOT bundled: io_put/cawl.py:11-14 looks for lift_templates/SILCAWL/SILCAWL.lift and calls SILCAWL_update.ensure_available() to fetch it when absent (the directory holds only SILCAWL_ReadMe.md, SILCAWL_update.py, __init__.py). This is a strong precedent for the licensing objection Kent raised in #165 — a Dekereke source needs no bundled data either, and there is an existing runtime-fetch idiom to point at.
- addentry does more than write(): lines 378-379 call self.getguids() and self.getsenseids(), re-walking the whole tree twice per entry. The per-entry cost is worse than the stated 'n full-file serializations'.
- fill_db_images has two hard-failure modes for a non-CAWL db that the 'safe' verdict papers over: line 2344 dereferences self.imgdir (set only via init_post_analang → get_imgdir at lift.py:128,189-192), and line 2357 divides by len(self.senses), so an import where every record is skipped raises ZeroDivisionError rather than producing an empty project.
- The collab write seam is installed at TWO sites — collab.py:1233/1237 in attach() and collab.py:520-521 in the reload path — so 'the write seam is one line' understates what a reuser must re-establish after a db swap.
- azt DOES observe a daemon-side lock: collab.py:243-262 retries a BUSY submit up to BUSY_RETRIES with a documented 'held project lock' log, and has a subtle branch for 'BUSY but the staged file is already consumed'. 'No locking of any kind' is false as stated.
- The .pot leaks more than a home directory: azt.pot lines 21-24 carry references of the form /home/kentr/bin/AZT/azt/file:/media/kentr/88C5-0968/azt_shallow*.git/... — Kent's USB bare repos. This strengthens 'never regenerate the .pot' beyond the stated reason.
- DkUserSettings can map a column that does not exist in the data file: the suffix mapping names Speaker2, which is not among SampleLang_full.xml's 42 columns. An importer reading sound-file suffixes must tolerate unmatched mappings.
- The local clone's oldest reachable commit is itself titled 'Merge branch main into testing' (2026-07-21); `git log --merges` returns 0 only because the shallow graft hides its parents. 'No merge commits' cannot be concluded from this checkout at all.
- HEAD of the working repo is Seth's own commit 2872868 (2026-09-02) adding planning/DEKEREKE_IO_PLAN.md and planning/DEKEREKE_CLOUD_PROMPT.md — the fork already carries local commits, which affects how a clean upstream PR branch must be cut.
- docs/NEXT_GENERATION.md specifies a Raspberry Pi server and a JavaScript/React client, i.e. Kent's own sketch is explicitly not a tkinter feature. Any pitch that offers to build it inside the desktop app is arguing against the author's stated design.
- frontend/vcs_ui.py:51 contains a user-facing string about Chorus, and backend/core/vcs.py:756 hard-exits (`if self.program.me: exit()`) on the Chorus-rescue check — so Chorus is not purely 'damage detection', and that exit() is a live hazard on Kent's machine.
- The plan's §3 role list (citation form, gloss(es), category, sound file, reference/id, notes) has no tone role even though §2 fact 6 notices the _Pitch columns — the sharper version of the 'tone is the argument' point is that the plan sees tone and then drops it at mapping time.