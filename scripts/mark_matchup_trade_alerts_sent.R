suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(tibble)
})

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_dir <- file.path("data", paste0("supercoach_league_", league_id))

path_pending_json <- file.path(data_dir, "pending_matchup_trade_alerts.json")
path_alert_log <- file.path(data_dir, "matchup_trade_alert_log.rds")

empty_alert_log <- tibble(
  alert_key = character(),
  alert_type = character(),
  round = integer(),
  opponent_team_id = integer(),
  opponent_team_name = character(),
  opponent_coach = character(),
  alert_message = character(),
  detected_run_ts = as.POSIXct(character()),
  sent_at = as.POSIXct(character())
)

if (!file.exists(path_pending_json)) {
  quit(save = "no", status = 0)
}

pending_payload <- read_json(path_pending_json, simplifyVector = TRUE)

if (is.null(pending_payload$alerts) || length(pending_payload$alerts) == 0) {
  quit(save = "no", status = 0)
}

pending_alerts <- bind_rows(pending_payload$alerts) %>%
  mutate(
    detected_run_ts = as.POSIXct(detected_run_ts, tz = "UTC"),
    sent_at = Sys.time()
  )

alert_log <- if (file.exists(path_alert_log)) readRDS(path_alert_log) else empty_alert_log

alert_log <- bind_rows(alert_log, pending_alerts) %>%
  distinct(alert_key, .keep_all = TRUE) %>%
  arrange(desc(sent_at), round, opponent_team_id)

saveRDS(alert_log, path_alert_log)
