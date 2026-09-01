# Settled decisions — Dekereke / A-Z+T / FlexText word collection

Decisions Seth made on 2026-09-02. Treat these as given; do not re-open them
without asking him. Rationale is kept short — the point is to stop later
sessions re-litigating.

## Licensing
1. **Dekereke is Rod Casali's software**; only its *file format* is read, from files
   the user already owns. No Dekereke code involved. Tell Rod as a courtesy.
2. **`rulingAnts/dekereke-pa-data-source` is Seth's own work** and he has agreed to
   **dual-license** it, so its column-mapping heuristics may be used in GPL-3.0 A-Z+T.
3. A-Z+T is **GPL-3.0**; the FlexText suite is **AGPL-3.0**. GPLv3 §13 permits
   combining GPL-3.0 code into an AGPL-3.0 work, so porting A-Z+T code *into* the
   FlexText suite is allowed. The reverse direction is not.

## Scope of the A-Z+T contribution
4. **Kent suggested XSLT.** A-Z+T already depends on `lxml` (`requirements.txt:21`) and
   already chains XSLT stylesheets in `io_put/xlp.py:92-171` over `xlptransforms/`, so an
   XSLT-driven transform adds no dependency and mirrors an existing in-repo pattern.
   (Whether *both* directions should be XSLT is still under test — XSLT 1.0 cannot mint
   GUIDs/timestamps, and Dekereke column names are per-database.)
5. **Do not target "LIFT" in general — target the LIFT A-Z+T itself emits.** Seth: "the
   million dollar question isn't the ENTIRE LIFT format, but rather what kind of LIFT
   output can/does AZT produce?" FLEx's full generality is out of scope.
6. Minimal, additive footprint; no refactoring of Kent's code. Optional-import guard so
   the feature is a no-op when unavailable, following the repo's own `nosound` precedent.

## Data model — Seth's own apps
7. **Dekereke XML is the native data model and primary export format**, not LIFT.
   Reason: Dekereke is *symmetric* about speakers — a flat table whose columns can be
   speakers (`Speaker2` in the sample data), elicitation frames, and `_Pitch` twins.
   LIFT is *hierarchical*: one canonical form with variants hanging off it. Seth's data
   (Lakes Plain: tiny phoneme inventories, heavy free variation, rapid sound change,
   optionally missing segments and syllables across speakers and dialects) is symmetric,
   so the native model must be too. **Capturing variation is a primary requirement.**
8. **LIFT export: yes. LIFT import: later, if practicable.** Tree→flat is the hard,
   lossy direction; flat→tree is mostly mechanical.
9. **LIFT export policy: primary + variants.** One LIFT entry per word; a
   user-designated primary speaker column becomes `<citation>`; other speaker/dialect
   columns become `<variant>` / dialect-tagged `<pronunciation>`. Keeps one word = one
   entry and stays legible to FLEx and WeSay. The export must state plainly what it
   dropped. (Rejected: one-entry-per-speaker, which loses word identity; primary-only,
   which is honest but archival-hostile.)

## Consequences for the converter
10. The import mapping dialog must include **"which column is the form to analyze?"** —
    A-Z+T can hold only one citation form per entry.
11. Export must **preserve the columns it could not represent** (stash the source column
    inventory + `Reference` at import) or a round trip silently deletes variation data.

## Linguistic assumptions (Fayu / Lakes Plain)
12. **Snider's tone tradition is usable for Fayu as a starting point** (Seth's judgement);
    Brendon Yoder's participatory method for **Abawiri** is the local precedent.
13. **Fayu has no noun morphology**, which makes tone-frame design *easier* than the Bantu
    case `docs/LEXICAL_CATEGORIES.md` worries about — no agreement morphology in the frame.
14. **Word order is rigidly head-final**, so frames cannot freely place material after a
    verb or before a noun head. The workaround is to vary the *tone* of the material in
    whatever slot exists (plus verb suffixes, postpositions/clitics, construction
    contrasts, and isolation) rather than to move the target word. Therefore **one-sided
    frames (`before` only) must be first-class**, not an edge case. A-Z+T's
    `ToneFrameDrafter` already stores frames as `{before, after}` pairs, either of which
    may be empty (`tasks/tasks.py:687-692`).
15. **Small lexicon.** Degrades cross-frame inference, not collection. Prefer wordlist
    growth; be sparing with slicing; report underdetermined contrasts as underdetermined.

## Architecture
16. **Do not fork A-Z+T into a PWA.** Kent already has a working pywebview backend
    (`frontend/ui_webview.py`, ~1,900 lines, ~30 widget classes; `Electron_Conversion.md`
    Phases 0-8 done except drag-and-drop). It is a *native webview driven by local
    Python* — no server, no host. If a browser-based A-Z+T is wanted, contribute there.
17. **Division of labour:** Seth's Tone Comparison App is the collection + consensus
    front end (already Dekereke-native, Android-deployable, multi-speaker agreement
    statistics). A-Z+T is the cross-frame UF analysis + XLingPaper reporting back end.
    **The Dekereke↔LIFT converter is the seam between them** — which is why it is worth
    doing first and separately.
18. A-Z+T has **no concept of multiple speakers or dialects** (one incidental hit, at
    `backend/langtags.py:461`). This is the decisive functional gap for Seth's region and
    is not a widget away.
