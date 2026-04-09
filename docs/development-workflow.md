# Development Workflow

## Goal

Make app work more reliable by separating:

- code changes
- local smoke checks
- deployed app checks
- user feedback after republish

## Fast Working Loop

### 1. Scope the task tightly

Use a request shape like:

- `Goal`
- `Context`
- `Constraints`
- `Output`
- `Verification`

Good example:

```text
Goal:
Fix the planner so reserve markers inherit correctly through bench swaps.

Context:
app.R planner state helpers and move schedule generation.

Constraints:
Do not change scoring weights.
Do not change Planner table column names.
Preserve captain/VC recommendation UI.

Output:
Edit app.R only.

Verification:
Rscript -e 'parse(file="app.R"); cat("parse ok\\n")'
Rscript scripts/smoke_check_app.R
Then rerun Walsh -> Edwards in the deployed app.
```

### 2. Make the smallest useful change

Avoid combining these in one turn unless necessary:

- planner state-machine rewrites
- scoring-model changes
- trade-page changes
- UI layout polish
- data refresh pipeline changes

### 3. Run local checks before republish

Always run:

```bash
Rscript -e 'invisible(parse(file="app.R")); cat("parse ok\n")'
Rscript scripts/smoke_check_app.R
```

### 4. Republish the app

Once changes are on `main`:

1. Republish from `main`
2. Open the deployed app
3. Check the relevant build stamp if one exists

### 5. Report feedback in a structured way

When a deployed behaviour is wrong, report:

- the exact tab
- the exact scenario
- the exact bad row/output
- what you expected instead

Best example:

```text
Planner tab
Scenario: Walsh -> Edwards
Bad row: Step 8 moves Howarth after Melbourne already locked
Expected: once Howarth locks on field he should be frozen
```

That is much faster to debug than “planner still broken”.

### 6. Use the in-app diagnostics pack

The Overview page now includes a `Diagnostics` action.

Use it when:

- a deployed table looks wrong
- a planner scenario behaves strangely
- a live trade/finance section looks stale
- you want to show the current app state without screenshots

Recommended workflow:

1. Open `Overview`
2. Click `Diagnostics`
3. Review the short summary block
4. Click `Download Diagnostics`
5. Paste the preview text back into chat or share the downloaded JSON contents

This is the preferred debugging loop for deployed app issues.

## Verification Levels

### Level 1: Parse check

Use after any code edit.

```bash
Rscript -e 'invisible(parse(file="app.R")); cat("parse ok\n")'
```

### Level 2: Repo smoke check

Use before push/republish.

```bash
Rscript scripts/smoke_check_app.R
```

### Level 3: Deployed app check

Use after republish for user-facing features.

Recommended checklist:

- app loads
- relevant tab loads
- no `Unavailable`/disconnect/runtime error
- scenario renders
- output obeys business rules

## Planner Validation Checklist

For Planner work, always check:

- captain/VC recommendations are sensible
- bogus team is legal
- reserve count stays at 4
- reserve markers move by bench tile, not abstract player label
- captain/VC markers inherit by tile
- locked players are not moved later
- final 14 plus 4 reserves match the intended target logic

## Trades / Live Data Validation Checklist

For Trades page work, always check:

- current round live data does not crash when there are zero live rows
- trade tables render for both historical and current-round cases
- cash calculations use the intended prior-round pricing logic
- league-wide trade log still renders after refresh

## Suggested Next Structural Improvements

These are worthwhile future cleanups:

1. Extract planner helpers into a dedicated `R/` file or module-like source file.
2. Extract trade-page finance helpers into a dedicated `R/` file.
3. Add a scripted planner regression runner for a few standard trade scenarios.
4. Add a small patterns file showing preferred Shiny helper style.

## Current Constraint

This repo still has a lot of logic in `app.R`, so requests should stay narrow and file-aware until more of the code is extracted cleanly.
