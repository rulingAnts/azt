# Cloud-session handoff — A-Z+T Dekereke work

Rewritten 2026-09-02, after the first day's work. Paste everything below the
line into a cloud Claude Code session started on `rulingAnts/azt`, branch
`dekereke-import-export`.

---

You are working in **A-Z+T** (`rulingAnts/azt`, a fork of `kent-rasmussen/azt`,
GPL-3.0) — Kent Rasmussen's Python/tkinter desktop app for community-based
phonology and orthography checking over LIFT XML. Seth Johnston is a field
linguist in Jayapura, Papua, Indonesia, working on **Fayu** (`iau_tmu`, Lakes
Plain family — a Papuan tone language with tiny phoneme inventories, heavy free
variation between speakers and dialects, and almost no morphology).

## Where things stand

**Dekereke XML import/export is built, tested and submitted as a draft PR:**
https://github.com/kent-rasmussen/azt/pull/173

It is a **draft on purpose** — Seth wants to drive it against a real database of
his own before asking Kent to review. Do not mark it ready.

The branch carries four commits and nothing else (no planning or research
files): the converter (`io_put/dekereke.py` + `dekereke_transforms/*.xsl`), an
upstream bug fix that blocks the feature, the chooser wiring, and
`docs/DEKEREKE.md`. 41 tests in `tests/test_dekereke.py`; the full suite passes
283 / 7 skipped / 0 failed.

## Read these first, in this order

1. `planning/DEKEREKE_DECISIONS.md` — eighteen settled decisions. **Treat them as
   given.** They cover licensing, why the transform targets *the LIFT A-Z+T
   emits* rather than LIFT in general, why Dekereke (not LIFT) is the native
   model for Seth's own apps, and the linguistic constraints of Lakes Plain
   languages.
2. `planning/ROADMAP.md` — the agreed phase order and the end-of-day status,
   including the four bugs filed upstream and what is parked.
3. `planning/DEKEREKE_IO_PLAN.md` — the original design.
4. `planning/research/` — ~500KB of verified findings from a research pass, with
   file:line evidence. `verify-corrections.md` records what an adversarial pass
   **overturned**, so prefer it where it disagrees with the others.
5. `CLAUDE.md` and `CONTEXT.md` — repo conventions and the project's domain
   vocabulary (analang, glosslang, tier, check, frame, group, UF group). Use
   those terms.

## What to work on

In priority order. Stop and report rather than inventing new scope.

### 1. Finish the converter's known gaps

These are listed as "not done, deliberately" in the PR, and each is small:

- **Copy the `.wav` files on import.** The importer records Dekereke's audio
  folder (from the sibling `-DkUserSettings.xml`) and attaches the right bare
  filename to each form, but moves no files. A-Z+T expects them in
  `<lift-dir>/audio` (`utilities/file.py:139-143`). Handle the folder being
  absent or unreachable — the path in the file is a Windows path
  (`C:\SampleLang\audio`) and will usually not exist on the user's machine, so
  ask rather than fail.
- **Re-import as update.** The row key is stored (`Dekereke-Reference`, declared
  in `header/fields`) precisely so a second import can update rather than
  duplicate. The flow is not built.
- **Let the user re-open the column mapping.** The mapping is persisted in the
  sidecar; there is currently no way back to the dialog after the first import.
  The Phonology Assistant add-on's convention is holding Shift while loading;
  something equivalent in the Advanced menu would fit this app better.

Keep the footprint minimal and additive — this is someone else's app and the
whole point is that Kent can merge it without disturbing his own code.

### 2. Write the illustrated user guide — prose, structure and diagrams only

Seth asked for a **step-by-step overview user guide of what A-Z+T does and how
to use it, with screenshots**, focusing especially on **wordlist collection**.

A research pass established what is and is not possible here; do not re-litigate
it (`planning/research/userguide.md`):

- **There is no step-by-step guide today and not one screenshot of the running
  app anywhere in the repo.** `docs/USAGE.md` is 221 lines of narrative
  reference with no numbered procedures, and Kent's own CHANGELOG lists
  "rework USAGE.md" as next up. The genuine gaps are the **wordlist-collection
  path**, which no document covers procedurally, and real UI captures.
- `docs/sorting_workflow.svg` already narrates the *vowel sorting* path screen by
  screen — match that house style rather than inventing one, and do not duplicate
  what it covers.
- **You cannot produce the screenshots.** Headless capture needs Xvfb, python3-tk,
  portaudio, Charis SIL, a multi-GB dependency install (torch, whisper,
  transformers, kivy, opencv) and two git clones, and three `wait=True` modal
  dialogs fire at boot and will stall an unattended run. Do not promise
  screenshots and do not spend a session fighting this.

So: **write 100% of the prose, the structure, and any new SVG diagrams in the
existing house style, plus a numbered shot-list** — each entry naming the exact
screen, the precondition to reach it, and what the reader should be looking at.
Seth's Mac supplies the PNGs later.

Two things the guide must cover that nothing else does:

- **Chapter 0: the menus are hidden by default.** Right-click → Show Menus. A
  reader cannot reach "Change to another Database", the digraph settings, or
  anything else in Advanced without this. It is the single highest-value
  screenshot in the guide.
- **The digraph settings, before any sorting.** A-Z+T decides whether a
  two-letter sequence is one sound or two, and seeds that decision from
  **English or French orthography** — `backend/core/profiles.py:46` has tables
  for `en` and `fr` only, picks by interface language when the analang has none,
  and applies them **silently** (`polygraphcheck()` never prompts on first run,
  and never prompts at all for polygraphs already in the English table, which
  includes `ou`, `ei`, `oi`). Everything downstream is sliced by syllable
  profile, so getting this wrong reshuffles every sort. `docs/DEKEREKE.md`
  already warns about it; the main guide needs to as well.

### 3. Only if Kent responds on the PR or the issues

Four issues were filed upstream on 2026-09-02, disclosed as AI-found:
[#169](https://github.com/kent-rasmussen/azt/issues/169) (`addentry` raises —
`xmletfns` has no `SubElement`),
[#170](https://github.com/kent-rasmussen/azt/issues/170)
(`gettransformsdir()` resolves under `utilities/`, so XLingPaper `compile()`
always returns early), [#171](https://github.com/kent-rasmussen/azt/issues/171)
(`slicebyerror()` uses the renamed `cawln` — **fixed in the PR**, because it
blocks opening any non-CAWL database), and
[#172](https://github.com/kent-rasmussen/azt/issues/172) (`CONTEXT.md`
documents the audio tag as `-x-audio`; the code builds `-Zxxx-x-audio`).

Respond to review comments and revise the PR. Do not open new PRs upstream, and
do not mark #173 ready for review.

## What is NOT yours

- **The test drive.** Seth's real Fayu databases are on his Mac only
  (`~/Documents/GIT/dekereke_fayu/Fayu_stable.xml`). You cannot reach them, and
  the walkthrough is a live session with him.
- **The Indonesian translation.** Fully scoped (1,684 strings; a locale folder is
  discovered by scan, so no code change) and deliberately **stopped**: Kent would
  reasonably want a native speaker to check it and Seth has not arranged that.
  Do not start it.
- **The FlexText Editor suite assignment API**, and the "am I reinventing the
  wheel" question. Both are parked in `planning/ROADMAP.md` for a later session
  with Fable. Do not start either.
- **Anything touching Seth's own repositories** other than this fork.

## Working rules

- Match the surrounding style. It is idiosyncratic — terse, `log.info`-heavy,
  generator-driven progress, four-space-ish continuation alignment. Follow it
  rather than modernizing it.
- Converter code imports nothing from `frontend/`.
- User-facing strings go through `from utilities.i18n import _`.
- Generate encoding fixtures in tests; never commit a re-saved Dekereke sample —
  the encodings are the payload.
- `pytest` must pass before each commit. Baseline: 283 passed, 7 skipped, 0
  failed.
- The public sample databases are at
  `https://github.com/rulingAnts/dekereke-pa-data-source` (`sample-data/`), with
  the format notes in that repo's `sample-data/README.md` and `HANDOFF.md`.

## Report back

Leave `planning/DEKEREKE_PROGRESS.md`: what you finished, what the tests cover,
what you had to guess, and the first thing the next session should do.
