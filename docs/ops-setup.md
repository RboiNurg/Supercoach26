# Operations Setup

This is the minimum setup to make the phone-triggered refresh, Google Drive storage, dashboard sync, and matchup email alerts work.

## 1. Add the GitHub Actions secrets

In GitHub, open the repo and go to:

`Settings -> Secrets and variables -> Actions -> New repository secret`

Add these names exactly:

- `SC_BEARER`
- `SC_GDRIVE_FOLDER_ID`
- `GDRIVE_SERVICE_JSON_B64`
- `ALERT_EMAIL_TO`
- `ALERT_EMAIL_FROM`
- `ALERT_EMAIL_SMTP_SERVER`
- `ALERT_EMAIL_SMTP_PORT`
- `ALERT_EMAIL_USERNAME`
- `ALERT_EMAIL_PASSWORD`

## 2. Get `SC_BEARER`

This is the SuperCoach bearer token used by the refresh scripts. It is not a normal password and it may rotate, so treat it as short-lived and sensitive.

Suggested way to get it:

1. Log into SuperCoach in a desktop browser.
2. Open developer tools.
3. Go to the `Network` tab.
4. Refresh the page or click a league/team page that causes an API request.
5. Find a request to a SuperCoach API path like `/api/nrl/classic/v1/...`.
6. Open the request headers.
7. Copy the value from the `Authorization` header, without the `Bearer ` prefix if you want to store only the token itself.

If the token stops working later, repeat the same process and update the secret.

## 3. Get Google Drive storage secrets

### `SC_GDRIVE_FOLDER_ID`

1. Create a folder in Google Drive for the SuperCoach data bundle.
2. Open the folder in your browser.
3. Copy the folder ID from the URL.

Example:

`https://drive.google.com/drive/folders/<THIS_PART_IS_THE_FOLDER_ID>`

### `GDRIVE_SERVICE_JSON_B64`

1. Create a Google Cloud project.
2. Enable the Google Drive API for that project.
3. Create a service account.
4. Create a JSON key for that service account and download it.
5. Share the target Google Drive folder with the service account email address as an editor.
6. Base64-encode the JSON file and store the resulting single-line string as the GitHub secret.

On macOS/Linux, you can generate the base64 value with:

```bash
base64 -i path/to/service-account.json | tr -d '\n'
```

## 4. Get Gmail alert secrets

The workflow currently uses SMTP, so Gmail is the easiest setup.

Recommended values:

- `ALERT_EMAIL_TO`: your Gmail address
- `ALERT_EMAIL_FROM`: your Gmail address
- `ALERT_EMAIL_SMTP_SERVER`: `smtp.gmail.com`
- `ALERT_EMAIL_SMTP_PORT`: `465`
- `ALERT_EMAIL_USERNAME`: your Gmail address
- `ALERT_EMAIL_PASSWORD`: a Gmail app password

To create the app password:

1. Turn on 2-Step Verification for the Google account.
2. Create an App Password in the Google account security settings.
3. Use that 16-character app password as `ALERT_EMAIL_PASSWORD`.

## 5. Manual inputs you can maintain

These files live inside the league data bundle and are included in the GPT export when present:

- `data/supercoach_league_21064/manual_inputs/origin_watch.csv`
- `data/supercoach_league_21064/manual_inputs/weekly_context_notes.md`

They are created automatically the first time the GPT pack is built if they do not already exist.

Use them for:

- probable Origin watchlists
- confirmed Origin teams when announced
- rumours / late mail notes
- personal strategy notes you want injected into the GPT pack

## 6. How to test

### Refresh pipeline

1. Add the secrets above.
2. Open the `SuperCoach Refresh` workflow in GitHub.
3. Run it manually with `Run workflow`.
4. Confirm the new bundle is written to Drive and the artifact finishes successfully.

### Analysis export

1. Open the `SuperCoach Analysis Export` workflow.
2. Run it manually.
3. Leave `refresh_first = true` if you want the latest live state first.
4. Download the artifact or open the latest bundle in Drive and inspect:
   - `analysis_export/latest_gpt_prompt_pack.md`
   - `analysis_export/latest_gpt_prompt_pack.txt`

### Dashboard

1. Start the app locally or deploy it.
2. Use `Refresh From Storage` to pull the latest Drive bundle.
3. Use `Build GPT Pack` inside the app when you want a fresh export without waiting for another workflow run.

## 7. Deploy the phone dashboard

Recommended host: Posit Connect Cloud.

Why this host:

- it supports Shiny apps directly from GitHub
- it supports encrypted app variables for the Drive secrets
- it gives you a public mobile-friendly URL you can open on Android
- it can automatically republish when you push new code

This repo now includes `manifest.json`, which Connect Cloud requires for R deployments.

### Publish steps

1. Make sure the repository is public, or use a paid Connect Cloud plan if you want private-repo publishing.
2. Sign in to Posit Connect Cloud.
3. Install the Connect Cloud GitHub app if prompted.
4. Click `Publish`.
5. Choose `Shiny`.
6. Select this repository.
7. Choose the default branch after you merge the PR.
8. Select `app.R` as the primary file.
9. In `Advanced settings`, add these app variables:
   - `SC_GDRIVE_FOLDER_ID`
   - `GDRIVE_SERVICE_JSON_B64`
   - `SC_LEAGUE_ID` = `21064`
10. Publish.

After that you will get a public app URL you can save to your phone home screen.

### What the deployed app will do

- load bundled seed data on first boot
- sync the latest data bundle from Google Drive
- let you tap `Refresh From Storage`
- let you build and download the GPT pack inside the app
- keep app writes in a runtime cache instead of the packaged repo directory

## 8. End-to-end phone test after merge

1. Merge the PR into the default branch.
2. Open GitHub on your phone.
3. Run `SuperCoach Refresh`.
4. Wait for the run to finish green.
5. Run `SuperCoach Analysis Export`.
6. Wait for that run to finish green.
7. Open the Connect Cloud app URL on your phone.
8. Tap `Refresh From Storage`.
9. Check the `Overview`, `Matchup`, `Signals`, and `Export` tabs.
10. Tap `Build GPT Pack` in the app and confirm the preview updates.
11. Confirm the Drive bundle updates and any matchup trade email alerts still work.

## Official setup references

- GitHub Actions secrets: https://docs.github.com/en/actions/security-for-github-actions/security-guides/using-secrets-in-github-actions
- Google service account keys: https://cloud.google.com/iam/docs/keys-create-delete
- Google Drive API quickstart: https://developers.google.com/workspace/drive/api/quickstart/python
- Google app passwords: https://support.google.com/accounts/answer/185833?hl=en
- Connect Cloud publish from GitHub: https://docs.posit.co/connect-cloud/user/publish/github.html
- Connect Cloud content settings and variables: https://docs.posit.co/connect-cloud/user/manage/content_settings.html
- Connect Cloud Shiny for R requirements: https://docs.posit.co/connect-cloud/user/content/shiny.html
