# Roadmap — agreed 2026-09-02

Seth's sequencing, in his own priority order. Each phase has a definition of done.
Do not start a later phase before the earlier one lands.

## Phase 1 (NOW) — Dekereke import/export for A-Z+T, as a PR to Kent

Build a Dekereke/LIFT import + export module for Kent Rasmussen's **Python** A-Z+T
(`kent-rasmussen/azt`). As simple, contained and modular as possible, but genuinely
user-friendly. Test it. Submit as a pull request from `rulingAnts/azt`.

Design constraints are in `DEKEREKE_DECISIONS.md`; the technical plan is in
`DEKEREKE_IO_PLAN.md`. Key ones: target *the LIFT A-Z+T emits*, not LIFT in general;
reuse the existing `lxml` + XSLT pattern from `io_put/xlp.py`; no refactoring of Kent's
code; optional-import guard so it no-ops when unavailable; the import mapping dialog must
ask which Dekereke column is the form to analyze.

**Done when:** the PR is open, tests pass headless, and an illustrated user-guide section
covers the import/export path (documentation makes a PR easier to accept).

## Phase 2 — FlexText Editor suite assignment API

Design (not yet build) a general API for the FlexText Editor suite that lets an app
developer define **a type of data/assignment** the researcher panel can send, receive and
manage — so the suite handles kinds of data other than interlinear texts.

Five surfaces to pin down:
1. **Assignment definition** — data type, scope/filter (which rows, which columns/fields),
   which fields are editable vs read-only for the assignee.
2. **Payload packaging and transport** — bundle format, audio handling, size limits,
   offline delivery and return.
3. **Device-level vs assignment-level settings** — device: UI language (EN/ID), speaker
   identity, recording setup. Assignment: filters, permissions, deadlines, instructions.
4. **Results schema + merge/conflict policy** at the panel, including multi-assignee
   agreement/disagreement.
5. **Identity and pairing** — already exists; make it data-type agnostic rather than
   redesigning it.

**Design it against THREE cases on paper, build for one.** Over-fitting to a single
consumer is the main risk of doing the API first:
- existing interlinear **text** assignments (the current, working case),
- the **Tone Comparison** bundle (Phase 3's consumer),
- a **wordlist collection with recordings** assignment (new words + a second speaker
  column + filtered rows) — the app Seth described wanting.

**Free validation before any code:** retroactively express the Tone Comparison App's
existing `.tncmp` bundle and results format in the API's terms. Bundle -> assignment
payload; the bundler's grammatical-category / syllable-pattern / reference-number filters
-> assignment scope; multi-speaker results + agreement statistics -> results merge. If the
API cannot describe what that app already does, the API is wrong.

**Done when:** a written API spec exists that all three cases can be expressed in.

## Phase 3 — Tone Comparison App as a FlexText suite satellite

Adapt/move `rulingAnts/tone_comparison_app` into the FlexText Editor suite as another
satellite app, as the **first real test case** of the Phase 2 API. Replaces its current
zip-file bundle handoff with the suite's pairing/assignment transport.

Note what it already has and must not lose: Dekereke-native data, researcher-side filtering
(category, syllable pattern, reference number, field mappings), offline Android + Windows
speaker app, picture/exemplar-based grouping with minimal text, multi-speaker comparison
with disagreement detection and agreement statistics.

**Done when:** a tone-matching assignment can be created in the researcher panel, delivered
to a paired device, completed offline, and returned — with no zip files.

## Phase 4 (LONG TERM, lower confidence) — A-Z+T inside the suite

Investigate an extension letting Kent's in-progress **pywebview/PWA** A-Z+T function within
the FlexText suite, so projects/devices/pairing/assignments work for it too.

**Open concern, flagged before any investment:** A-Z+T's data model holds one citation form
per entry, while the suite's payload here is Dekereke-shaped and speaker-columnar. Making
A-Z+T a satellite means either teaching it the variation axis (a large change to someone
else's app) or flattening on the way in and losing the variation — which is the whole point
of using Dekereke. The integration that probably makes sense is **"the suite hands A-Z+T a
project and takes it back"** — i.e. Phase 1's converter at a different scale — rather than
A-Z+T running inside the suite. Decide this deliberately; do not drift into it.
