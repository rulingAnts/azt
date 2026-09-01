# Cloud-session handoff prompt — Dekereke import/export for A-Z+T

Paste everything below the line into a fresh cloud Claude Code session started
on `rulingAnts/azt`, branch `dekereke-io-plan`.

---

You are working in **A-Z+T** (`rulingAnts/azt`, a fork of `kent-rasmussen/azt`,
GPL-3.0) — a Python/tkinter desktop app for community-based phonology and
orthography checking over LIFT XML lexicons. The end goal is a **pull request to
`kent-rasmussen/azt`** adding **Dekereke XML import and export**.

## Start here

Read, in this order:

1. `planning/DEKEREKE_IO_PLAN.md` — the design. It is the spec for this work:
   the Dekereke format, the eight things that break naive readers, where the
   code lands in A-Z+T, the increments, and the licensing constraint.
2. `CLAUDE.md` and `CONTEXT.md` — repo conventions and the project's domain
   vocabulary (analang / glosslang / audiolang / tier / check). Use these terms.
3. `io_put/lift.py` (`LiftXML`, and `addentry` at ~L333), `io_put/cawl.py`,
   `backend/core/templates.py`, `io_put/export.py`, `io_put/xlp.py`.

Reference material for the Dekereke format — a public repo, **read-only for
you**: `https://github.com/rulingAnts/dekereke-pa-data-source`. Fetch
`sample-data/` (three real-shaped databases + a `-DkUserSettings.xml`),
`sample-data/README.md`, and `HANDOFF.md`. The C# in `src/DekerekeToPa/` is a
**behavioral reference only** — it is AGPL and must not be ported line-by-line
into this GPL-3.0 repo (see §7 of the plan). Reimplement in Python from the
format description and the samples.

## What to do

Work the increments in §4 of the plan, in order, one commit each, tests with
each. Do not skip ahead to the UI: increments 1–3 (`io_put/dekereke.py` reader,
column-mapping heuristics, `to_lift`) are the substance and must be fully tested
headless before any tkinter code is written.

Constraints:

- **Do not restructure existing code.** This is an additive contribution to
  someone else's project; a PR that refactors `lift.py` will not be merged.
  Match the surrounding style (it is idiosyncratic — terse, `log.info`-heavy,
  generator-driven progress; follow it rather than modernizing it).
- Converter code imports nothing from `frontend/`.
- All user-facing strings go through `from utilities.i18n import _`.
- Generate encoding fixtures in the tests themselves; never commit a re-saved
  Dekereke sample (the encodings are the payload).
- Add any new module to the list in `tests/test_import_smoke.py`.
- `pytest` must pass headless before each commit.

## What to leave to Seth

- Opening the PR upstream, and the questions in §6 of the plan (they are for
  Kent Rasmussen, the upstream maintainer — draft them, don't send them).
- Any decision about relicensing the `dekereke-pa-data-source` heuristics.
- Anything that touches Seth's real Dekereke databases; work from the samples.

## Report back

When you stop, leave a short `planning/DEKEREKE_PROGRESS.md`: which increments
are done, what the tests cover, what you had to guess about the format, and the
first thing the next session should do.
