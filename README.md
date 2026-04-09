# Supercoach26

This repository contains the strategy, data model, and decision logic for an NRL SuperCoach decision-support system.

The goal is not just to rank players, but to make better weekly and season-long decisions by combining player performance, pricing, breakevens, fixtures, team context, squad structure, and opponent behaviour into one decision framework.

## Core idea

The system is designed to answer:

- what is the best move right now
- what is the best move for the next 2 to 5 rounds
- what is the best move for the season overall
- when a short-term edge is worth taking
- when a trade should be avoided despite looking attractive in the current round

This project assumes regularly refreshed data and aims to support both:

- longer-term season strategy
- during-round tactical decisions as new information appears before games lock

## Planned components

### 1. data collection
Scripts to pull and standardise:

- player prices
- breakevens
- scoring history
- minutes and role indicators
- team lists and late changes
- fixture and matchup context
- team performance trends
- squad history
- league and opponent history
- cash movement and trade inference where possible

### 2. lookup tables
Clean, stable tables that the engine can query, including:

- master player table
- player scoring component history
- fixture and matchup table
- team list and role certainty table
- cash generation model
- squad structure table
- opponent behaviour table
- captaincy table
- trade candidate comparison table
- long-horizon planning table

### 3. decision engine
A strategy layer that weighs:

- projected points
- cash generation
- structural value
- flexibility
- bye and Origin coverage
- captaincy depth
- opportunity cost
- opponent-specific considerations
- long-term trade preservation

### 4. strategy playbook
A SuperCoach-specific ruleset that defines how the engine should think and how competing priorities are resolved.

## Intended workflow

1. Refresh data before lockout windows
2. Rebuild lookup tables
3. Assess current squad, market options, and opponent context
4. Compare no-trade, one-trade, two-trade, and boost scenarios
5. Recommend the move with the best balance of:
   - immediate gain
   - medium-term gain
   - season-long value
   - acceptable risk

## Repo purpose

This repo is intended to work well with Codex and GitHub-based iteration.

ChatGPT can be connected to GitHub through **Settings → Apps → GitHub**, where repository access is authorised. OpenAI’s Codex admin setup documentation also notes that Codex cloud currently works with GitHub cloud-hosted repositories. :contentReference[oaicite:0]{index=0}

## Development workflow

This repo now includes repo-specific operating guidance for agentic coding work:

- [AGENTS.md](AGENTS.md)
- [docs/development-workflow.md](docs/development-workflow.md)
- [docs/ops-setup.md](docs/ops-setup.md)

### Minimum verification before republish

```bash
Rscript -e 'invisible(parse(file="app.R")); cat("parse ok\n")'
Rscript scripts/smoke_check_app.R
```

### Current coding reality

- The app currently lives mainly in `app.R`
- data refresh and export logic live in `scripts/`
- bundled league data lives in `data/supercoach_league_21064/`

For now, the safest way to work is:

1. keep tasks tightly scoped
2. inspect relevant code first
3. make the smallest change that fits the existing pattern
4. run the verification commands above
5. republish from `main`

## Design principles

- role over hype
- repeatable scoring over fluky spikes
- structure over impulse
- preserve trades unless the edge is real
- short-term moves must justify long-term cost
- all recommendations should be explainable
