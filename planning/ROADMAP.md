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

**Design it against FIVE cases on paper, build for one.** Over-fitting to a single
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

**Additional use cases Seth raised (2026-09-02) — file these into the design:**
- **Scripture media trial content distribution.** His scripture-media trial-content app
  currently ships `.smbundle` files that are "gigantic and unwieldy". Under the suite it
  would instead **manage available content and limits on that content remotely, and sync
  content and policy changes**. This case stretches the API in a direction the others do
  not: it is not "send data out, get edited data back" but **content entitlement and
  policy** — what a device is allowed to hold, for how long, revocable and updatable
  remotely. The API needs device-level *policy* as a first-class concept, not just
  device-level *settings*.
- **Dictionary development (LIFT, not Dekereke).** Once a project graduates from phonology
  database building to dictionary work, **LIFT is the right model** — senses, meaning
  components, lexical relations, roots/stems, and an already-established written form.
  That data genuinely is a tree.

**Design conclusion that follows: the API must be payload-agnostic — flat-table AND tree.**
Do not bake Dekereke's flat, speaker-columnar model into the assignment API. The same
project is expected to move from Dekereke-shaped data (phonology stage, where symmetric
speaker variation is the point) to LIFT-shaped data (dictionary stage, where hierarchy and
relations are the point). Scoping/filtering therefore cannot assume "rows and columns" —
it needs a general notion of "which part of the payload this assignee may see and edit"
that degrades to rows/columns for tabular data and to subtrees/fields for tree data.

**Corollary:** the Dekereke->LIFT converter is on the critical path for Seth's *own*
workflow, not only for the A-Z+T contribution — it is how a project graduates from the
phonology stage to the dictionary stage.

**Done when:** a written API spec exists that all five cases can be expressed in.

**Owner:** Seth wants **Fable** to do this planning work in a later session. Do not start
it in a session focused on the A-Z+T pull request.

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

---

## Open questions parked for Fable (not for the A-Z+T PR session)

1. **The Phase 2 API design itself** (five use cases above), including the flat-vs-tree
   payload-agnostic requirement and device-level *policy* as distinct from settings.

2. **"How much am I reinventing the wheel?"** — Seth's own framing, 2026-09-02: A-Z+T looks
   very similar in *intent* to his Tone Comparison App. He has already built his wheel; the
   question is whether to keep extending it or to "use an existing wheel and maybe add
   spokes or rims to it."

   Evidence gathered today, for whoever takes this up — do not treat it as a verdict:
   - **A-Z+T has no concept of multiple speakers or dialects** (`backend/langtags.py:461` is
     the only hit, and it is incidental formatting). Capturing speaker/dialect variation is
     a *primary* requirement for Lakes Plain languages. This is not a widget away — LIFT
     gives one citation form per entry, and the sort/verify path is built on that.
   - **The Tone Comparison App is already Dekereke-native**, already ships to Android
     offline, already filters by category/syllable pattern/reference at bundling time, and
     already compares multiple speakers with disagreement detection and agreement
     statistics. A-Z+T does none of that.
   - **A-Z+T has what the Tone Comparison App lacks:** cross-frame analysis (deriving
     underlying-form groups from correspondences across syntactic frames) and XLingPaper
     report generation. Seth's team has not reached those stages yet.
   - **A-Z+T is further along than expected on a browser UI:** `frontend/ui_webview.py` is a
     ~1,900-line pywebview backend with ~30 widget classes; `Electron_Conversion.md` has
     Phases 0-8 done except drag-and-drop. It is a *local* webview, no server.
   - Licensing permits porting A-Z+T (GPL-3.0) into the AGPL-3.0 FlexText suite; not the
     reverse.

   The honest shape of the question is probably not "replace one with the other" but
   "which stages does each own, and what is the seam" — see DEKEREKE_DECISIONS.md #17.

   **Seth's added consideration (2026-09-02):** A-Z+T has a very competent developer
   actively developing and maintaining it. If Seth can use Kent's tool and *suggest*
   modifications and fixes, maintaining a parallel app may not be worth his time and
   energy — though how willing Kent is to take those suggestions remains to be seen. The
   Dekereke PR is itself the cheapest possible experiment on that question: it will show
   how Kent responds to an outside contribution before anything larger is bet on him.

3. **The pywebview mini-shell idea (Seth, 2026-09-02) — promising, file it with Phase 4.**
   Rather than running a Python app inside a PWA, keep A-Z+T installed natively on a
   coworker's computer and add PWA-*ish* functionality alongside it: a small
   pywebview-hosted browser shell that does nothing but the FlexText suite's
   pairing and assignment send/receive interface. A-Z+T keeps its own data and UI; the
   shell is a sync satellite that hands it a project and takes it back.

   Why this is the right shape: it sidesteps the variation-axis problem entirely (nothing
   is flattened on the way in — the shell moves whole projects, not rows), it needs no
   change to A-Z+T's data model, and it reuses the pywebview dependency Kent is already
   adding. It also means the suite's assignment API must support an assignment whose
   payload is "a whole project file plus its audio", not only "filtered rows" — a sixth
   case for the Phase 2 design.

---

## Status at end of 2026-09-02

**Phase 1 is done and submitted.** PR: https://github.com/kent-rasmussen/azt/pull/173
(branch `dekereke-import-export`, cut clean from `origin/main` — it carries only
the four feature commits, none of the planning or research files on
`dekereke-io-plan`).

What is in it: `io_put/dekereke.py` + `dekereke_transforms/*.xsl` (XSLT both
directions, per Kent's suggestion — no new dependency, mirrors `io_put/xlp.py`),
the chooser entry and column-mapping dialog, `docs/DEKEREKE.md`, and 41 tests.
Full suite on that branch: 283 passed, 7 skipped, 0 failed.

Verified by hand against both anonymised sample databases (15-column UTF-8 and
41-column UTF-16LE): both round-trip with **zero differing cells**, CRLF and BOM
preserved, `<qvp_acoustic_data_>` blocks intact.

**Bugs filed upstream** (AI-found, disclosed as such, on Kent's repo not the fork):
- #169 `LiftXML.addentry()` — `utilities.xmletfns` has no `SubElement`; the only
  create-an-entry path raises.
- #170 `gettransformsdir()`/`getstylesheetdir()` resolve under `utilities/`, so
  XLingPaper `compile()` always returns early — likely the whole reason the
  XeLaTeX path "isn't working yet".
- #171 `slicebyerror()` uses the renamed `Sense.cawln` — **fixed in the PR**,
  because it blocks opening any non-CAWL database.
- #172 `CONTEXT.md` documents the audio tag as `-x-audio`; the code builds
  `-Zxxx-x-audio`.

**Findings that change the AZT-vs-Tone-Comparison question** (see the parked
question above — these are evidence, not a verdict):
- A-Z+T **defers to a curated syllable-profile column**: it slices by the
  confirmed profile and its fill-in pass refuses to overwrite one. The importer
  now distinguishes a checked profile column from a generated one, so Seth's
  researcher-curates-profiles workflow carries into A-Z+T intact.
- Segment/sequence analysis **is** user-controlled (`Advanced` ▸ `Digraph and
  Trigraph settings`) — the option Rod Casali declined to add to Dekereke. But
  the defaults come from English/French *orthography*
  (`backend/core/profiles.py:46`, tables for `en` and `fr` only), are chosen by
  interface language when the analang has none, and are applied **silently** —
  `polygraphcheck()` never prompts on first run, and never prompts at all for
  polygraphs already in the English table (`ou`, `ei`, `oi`…).

**Parked, not abandoned:**
- **Indonesian translation.** Scoped: 1,684 strings, `translations/<locale>/
  LC_MESSAGES/azt.{po,mo}`, discovered by folder scan (`main.py:184-192`) so it
  needs **no code change**. A glossary grounded in the team's own Dekereke column
  names is in the session scratchpad. **Stopped because Kent would reasonably
  want a native speaker to check it, and Seth does not have time to arrange that
  now.** Do not restart without that.

## Next session: the A-Z+T test drive

Import a real Fayu database and walk Seth through A-Z+T screen by screen, so he
can judge fit himself. His data:
`/Users/Seth/Documents/GIT/dekereke_fayu/Fayu_stable.xml` (a git repo of
Dekereke backups; `Fayu_stable.xml` is the working copy). Another copy, with a
`-DkUserSettings.xml` beside it, is in `~/Desktop/Dekereke dari Pk Seth/`.

**Do the digraph settings first**, before any sorting — see the finding above.
Then decide, with the data in front of you, whether paradigm columns
(`CMPLalt`, `INCMP`, `IMP-re`, `SVC`, `SEQ`) belong as **frames** (sortable,
tone twins have a home) or as **second-form fields** (A-Z+T's native
plural/imperative machinery, which is coded but reachable from no menu —
`tasks/chooser.py:159-201`, a two-line fix worth asking Kent for).

The question the test drive has to answer: **does one-form-per-word cost too
much**, given rampant free variation across speakers and dialects.

---

## Future research question (noted 2026-09-02, not started)

**Can Phonology Assistant read A-Z+T's LIFT output directly, or does it require an
actual FLEx database?**

PA's data-source list includes FieldWorks projects, Toolbox SFM and a few others;
whether it can take a plain LIFT file — and specifically the header-less,
non-namespaced LIFT profile A-Z+T writes (see `planning/research/lift-profile.md`)
— is unestablished.

If it cannot, build a **PA add-on presenting A-Z+T LIFT as a data source**, and
offer it upstream, so anyone using A-Z+T can also open their data in Phonology
Assistant if they want or need to.

The architecture is already proven: `rulingAnts/dekereke-pa-data-source` does
exactly this for Dekereke XML — PA scans `<install>\AddOns\*.dll` for a
`PaAddOnManager` class, and the add-on hooks `BeforeLoadingDataSources` /
`AfterLoadingDataSources` to swap in a generated, fully field-mapped Toolbox SFM
file for the duration of the read. An A-Z+T variant would differ only in the
reader (LIFT instead of Dekereke) and the field mapping. `HANDOFF.md` in that
repo has every hook point with PA source line references.

Worth checking first, cheaply: whether PA 4.x already accepts LIFT, and whether
`docs/FLEX_COLLABORATION.md` says anything about the PA path.
