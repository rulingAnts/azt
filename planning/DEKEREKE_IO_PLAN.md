# Dekereke XML import/export for A-Z+T — big-picture plan

Status: **plan only**, written 2026-09-02. No code yet.
Target: a contribution back to `kent-rasmussen/azt` (GPL-3.0) as a pull request
from the fork `rulingAnts/azt`.

## 1. Goal

Let an A-Z+T user (a) start a project from an existing **Dekereke** phonology
database, and (b) push A-Z+T's results back out as Dekereke XML, so a linguist
using Rod Casali's Dekereke ([casali.canil.ca](https://casali.canil.ca/)) can
run A-Z+T's sorting/checking workflow over data they already have, and return
the checked forms to Dekereke.

Import is the more valuable half and should ship first.

## 2. The Dekereke file format (what the importer must survive)

Reference data and a proven reader implementation (C#) live in the public repo
**`rulingAnts/dekereke-pa-data-source`** — `sample-data/`, `HANDOFF.md`, and
`src/DekerekeToPa/`. See §7 for the licensing constraint on reusing it.

```xml
<?xml version="1.0" encoding="utf-8"?>
<phon_data>
  <data_form>
    <Reference>0015</Reference>
    <Category>Noun</Category>
    <SoundFile>0015_rawa.wav</SoundFile>
    <IndonesianGloss>rawa</IndonesianGloss>
    <Phonetic>tei</Phonetic>
    <Tulisan>tei</Tulisan>
    <Catatan>periksa dengan penutur lain</Catatan>
    <kosong />
  </data_form>
  ...
</phon_data>
```

Non-negotiable facts, each of which has bitten the C# implementation:

1. **Column names are user-defined per database.** The child element names of
   `<data_form>` *are* the columns. Nothing may be hard-coded. Two real
   databases share only a handful of column names. Names may contain `-` and
   `.` (`IMP-re`, `Orth.practice`).
2. **Three on-disk encodings are all live in the field**: UTF-16LE + BOM with
   `encoding="utf-16"` (older releases — including Seth's own working
   database), UTF-8 + BOM, and plain UTF-8 with no BOM (current release).
   → **Hand the raw byte stream to the XML parser** and let it resolve encoding
   from BOM + declaration. Never pre-decode to `str`, never sniff.
3. **Empty fields are self-closing elements** (`<kosong />`), not absent.
4. **Sound files are bare names** (`0015_rawa.wav`). The folder lives in a
   sibling per-user settings file `<basename>-DkUserSettings.xml`, element
   `<sound_file_path>`. Import must find that file, and degrade gracefully if
   it is missing (ask the user for the audio folder).
5. **Ignore `<qvp_acoustic_data_>` nested blocks** entirely.
6. `_Pitch` twin columns accompany verb-paradigm columns; elicitation-frame
   columns look like `goodX`, `Xbad`, `Xstraight`.
7. **Records with an empty phonetic form must be skipped**, not imported as
   empty entries.
8. CRLF line endings; preserve them on write.

## 3. Where this lands in A-Z+T

A-Z+T's data model *is* LIFT (`io_put/lift.py`, ~5.6k lines). Dekereke support
is therefore a **converter at the edges**, not a second data model. Do not
introduce a parallel database abstraction.

### Import — follow the CAWL precedent

The existing "build a new LIFT project from an external wordlist" path is:

| Piece | File |
|---|---|
| `WordListTemplate` base — code validation, filename, `db.init_post_analang()` | `backend/core/templates.py` |
| `CAWL(WordListTemplate)` — concrete external source | `backend/core/templates.py` |
| loader that returns a `lift.LiftXML` | `io_put/cawl.py` |
| UI entry points (`templates.CAWL(self.program, analang=…)`, `makeCAWLdemo`) | `frontend/ui_shell.py` (~L3170, ~L3276) |

So the shape is:

- `io_put/dekereke.py` — **new**. Pure parse/convert, no frontend imports:
  - `DekerekeXML` — byte-stream parse, column inventory, records as dicts,
    settings-file lookup for the audio path.
  - `column_guesses(columns)` — heuristic mapping (English + Indonesian
    column-name cues) from Dekereke columns → A-Z+T roles: citation form
    (analang), gloss(es) (glosslang), grammatical category, sound file,
    reference/id, notes. Return ranked guesses, never a silent choice.
  - `to_lift(dekereke, mapping, analang, glosslangs)` → a `lift.LiftXML`
    populated via `LiftXML.addentry(...)` (see `io_put/lift.py:333` for the
    kwargs contract: `form={analang: …, glosslang: …}`, `ps=…`).
- `backend/core/templates.py` — add `Dekereke(WordListTemplate)` alongside
  `CAWL`, reusing `verify_code` / `verify_writeable`.
- `frontend/ui_shell.py` — a file picker for the `.xml`, then a **mapping
  confirmation dialog** (the one piece of new UI), then the existing
  new-project flow. Audio: copy or reference the wavs into the project's audio
  dir per `io_put/sound.py` conventions, attaching them as
  `<form lang="…-x-audio">` the way A-Z+T already does (see `CONTEXT.md` on
  `audiolang`).

**The mapping dialog is the crux of the UX.** Column names are per-database, so
guessing + one confirmation is the only workable design; the same conclusion
was reached and validated in `dekereke-pa-data-source`. Persist the confirmed
mapping in project settings (`settings/`) and offer a way to reopen it.

### Export — follow the XLingPaper precedent

`io_put/xlp.py` (500 lines) writes a foreign XML format out of the LIFT model;
`io_put/export.py` holds the `Exporter` base (generator-driven with progress
`yield`s, which the task UI consumes). Add:

- `io_put/dekereke.py::from_lift(lift, mapping)` — write `<phon_data>` with the
  original column inventory where a source mapping is known.
- Two modes, and the plan should not fudge the difference:
  - **Round-trip update** (preferred when the project was imported from
    Dekereke): keep the original column set and record order, match records by
    the stored Dekereke `Reference`, and write back only mapped columns. Store
    the source path + column inventory at import time to make this possible.
  - **Fresh export** (project not from Dekereke): emit a minimal sane column
    set (`Reference`, `Phonetic`, gloss, `Category`, `SoundFile`).
- Encoding on write: plain UTF-8 (current Dekereke release) by default, with an
  option to match the source file's encoding on round-trip.

## 4. Suggested increments (each a reviewable commit)

1. `io_put/dekereke.py` reader + tests, with fixtures generated in-test for all
   three encodings (do **not** commit re-saved sample files — the encodings are
   the point).
2. Column-mapping heuristics + tests over both sample column inventories.
3. `to_lift()` + tests asserting entry counts, skipped-empty-phonetic records,
   and gloss/citation language tagging.
4. `templates.Dekereke` wiring, no UI.
5. Mapping dialog + menu item in `frontend/ui_shell.py`; settings persistence.
6. Audio wiring (settings-file path, missing-folder fallback).
7. Export: fresh mode.
8. Export: round-trip mode.

## 5. Testing

`pytest` from the repo root; see `CLAUDE.md` and `tests/README.md`. Keep the new
converter tests **frontend-free** (the repo's existing rule for `backend/core`);
they should run headless with no Tk. Add the new module to the import smoke test
list in `tests/test_import_smoke.py`.

## 6. Open questions for upstream (ask Kent before the PR)

- Is a second import source welcome in `templates.py`, or does he want a
  general "importers" registry first?
- Where should per-project import mappings live in `settings/`?
- Does he want export as a Task (progress-yielding `Exporter` subclass) or a
  plain menu action?
- i18n: all user-facing strings go through `utilities.i18n._` and land in
  Crowdin — confirm the workflow for adding new strings.

## 7. Licensing constraint (read before copying any code)

`kent-rasmussen/azt` is **GPL-3.0**. `rulingAnts/dekereke-pa-data-source` is
**AGPL-3.0-or-later**. AGPL-licensed source may not simply be dropped into a
GPL-3.0 project. Seth holds the copyright on that repo, so the clean options
are: (a) reimplement in Python from the *specification* above and from the
sample data (facts and formats are not copyrightable), or (b) Seth explicitly
dual-licenses the specific heuristics under GPL-3.0 for this contribution.
**Default to (a)** — the C# is a reference for behavior, not a source to port
line by line.
