# Operations Setup

This project now uses a GitHub-first flow:

- GitHub Actions refreshes the data and commits refreshed `.rds` files back to `main`
- Posit Connect Cloud publishes the app from `main`
- Connect Cloud should auto-republish on push, so new refresh commits can roll into the app without Google Drive
- the app itself reads the deployed repo snapshot and can reload that bundled snapshot on demand

## 1. Required GitHub Secrets

In GitHub:

`Settings -> Secrets and variables -> Actions -> New repository secret`

Add these:

- `SC_BEARER`
- `ALERT_EMAIL_TO`
- `ALERT_EMAIL_FROM`
- `ALERT_EMAIL_SMTP_SERVER`
- `ALERT_EMAIL_SMTP_PORT`
- `ALERT_EMAIL_USERNAME`
- `ALERT_EMAIL_PASSWORD`

Google Drive secrets are no longer part of the critical path.

## 2. Get `SC_BEARER`

1. Log into SuperCoach in a desktop browser.
2. Open DevTools.
3. Go to `Network`.
4. Trigger a SuperCoach API request.
5. Open a request to `/api/nrl/classic/v1/...`
6. Copy the `Authorization` bearer token.

If the token expires later, repeat the same process and update the secret.

## 3. Get Gmail Alert Secrets

Recommended values:

- `ALERT_EMAIL_TO`: your Gmail address
- `ALERT_EMAIL_FROM`: your Gmail address
- `ALERT_EMAIL_SMTP_SERVER`: `smtp.gmail.com`
- `ALERT_EMAIL_SMTP_PORT`: `465`
- `ALERT_EMAIL_USERNAME`: your Gmail address
- `ALERT_EMAIL_PASSWORD`: a Gmail app password

To create the app password:

1. Turn on 2-Step Verification.
2. Open Google account security settings.
3. Create an App Password for `Mail`.
4. Store that 16-character app password in `ALERT_EMAIL_PASSWORD`.

## 4. Manual Inputs You Can Maintain

These stay in the repo data bundle and are included in the GPT export:

- `data/supercoach_league_21064/manual_inputs/origin_watch.csv`
- `data/supercoach_league_21064/manual_inputs/weekly_context_notes.md`

Use them for:

- probable Origin watchlists
- confirmed Origin teams
- rumours / late mail notes
- your personal strategy notes

## 5. Workflows

### `SuperCoach Refresh`

What it does:

- runs on schedule and manual trigger
- pulls live data
- rebuilds the saved `.rds` outputs
- commits refreshed data back to `main`
- sends matchup trade emails if configured

### `SuperCoach Storage Reset`

What it does:

- wipes generated league storage under `data/supercoach_league_21064`
- preserves `manual_inputs`
- commits the cleared state to `main`

### `SuperCoach Analysis Export`

What it does:

- optionally refreshes first
- builds the GPT prompt pack
- uploads the export as a workflow artifact

## 6. Posit Connect Cloud

Publish from:

- repo: `RboiNurg/Supercoach26`
- branch: `main`
- primary file: `app.R`

Use a fresh publish from `main`, not an old `codex/...` draft branch.

Recommended app variable:

- `SC_LEAGUE_ID=21064`

### Expected behavior

- the app boots from the bundled repo snapshot
- if Connect Cloud auto-republish on push is enabled, refresh commits to `main` should roll forward into the deployed app
- inside the app, `Reload Bundled Snapshot` reloads the current deployed snapshot into the runtime cache

## 7. Test Sequence

### Data refresh test

1. Open GitHub Actions.
2. Run `SuperCoach Refresh` on `main`.
3. Wait for a green run.
4. Confirm the run created a new `[auto] Refresh SuperCoach data ...` commit on `main`.

### Reset test

1. Open GitHub Actions.
2. Run `SuperCoach Storage Reset` on `main`.
3. Enter `WIPE`.
4. Wait for a green run.
5. Then run `SuperCoach Refresh` again.

### Dashboard test

1. Publish or republish the app from `main`.
2. Open the app URL.
3. Click `Reload Bundled Snapshot`.
4. Check:
   - `Current Round`
   - `Snapshot Round`
   - `League Financial Snapshot`
   - `Fixture Runway`
   - `League Table`

### GPT export test

1. Run `SuperCoach Analysis Export`.
2. Download the artifact.
3. Inspect:
   - `latest_gpt_prompt_pack.md`
   - `latest_gpt_prompt_pack.txt`
   - `latest_gpt_prompt_pack_meta.json`

## 8. Simple Operating Rule

If you changed code:

1. push/merge to `main`
2. let Connect Cloud republish from `main`
3. run `SuperCoach Refresh` if you also want fresh data

If you only want fresh data:

1. run `SuperCoach Refresh`
2. wait for the auto-refresh commit on `main`
3. reopen the app or reload the deployed snapshot

## References

- GitHub Actions secrets: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions
- Connect Cloud publish from GitHub: https://docs.posit.co/connect-cloud/user/publish/github.html
- Connect Cloud content settings and variables: https://docs.posit.co/connect-cloud/user/manage/content_settings.html
- Connect Cloud Shiny for R requirements: https://docs.posit.co/connect-cloud/user/content/shiny.html
