event_name <- Sys.getenv("REFRESH_GATE_EVENT_NAME", Sys.getenv("GITHUB_EVENT_NAME", "manual"))
timezone_name <- Sys.getenv("REFRESH_GATE_TZ", "Australia/Sydney")
league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
daily_times_raw <- Sys.getenv("DAILY_REFRESH_TIMES_SYD", "08:05,13:05,18:05")
pregame_minutes_raw <- Sys.getenv("PRE_GAME_REFRESH_MINUTES", "60,30,15")
daily_tolerance_minutes <- suppressWarnings(as.numeric(Sys.getenv("DAILY_TOLERANCE_MINUTES", "4")))
pregame_tolerance_minutes <- suppressWarnings(as.numeric(Sys.getenv("PRE_GAME_TOLERANCE_MINUTES", "4")))
now_override <- Sys.getenv("REFRESH_GATE_NOW", "")

if (is.na(daily_tolerance_minutes)) {
  daily_tolerance_minutes <- 4
}

if (is.na(pregame_tolerance_minutes)) {
  pregame_tolerance_minutes <- 4
}

split_csv <- function(x) {
  if (!nzchar(x)) {
    return(character())
  }

  out <- strsplit(x, ",", fixed = TRUE)[[1]]
  trimws(out[nzchar(trimws(out))])
}

daily_times <- split_csv(daily_times_raw)
pregame_minutes <- suppressWarnings(as.numeric(split_csv(pregame_minutes_raw)))
pregame_minutes <- pregame_minutes[!is.na(pregame_minutes)]

escape_output_value <- function(x) {
  x <- gsub("%", "%25", x, fixed = TRUE)
  x <- gsub("\r", "%0D", x, fixed = TRUE)
  x <- gsub("\n", "%0A", x, fixed = TRUE)
  x
}

emit_output <- function(name, value) {
  cat(name, "=", escape_output_value(value), "\n", sep = "")
}

parse_now <- function(x) {
  if (!nzchar(x)) {
    return(Sys.time())
  }

  parsed <- suppressWarnings(as.POSIXct(x, tz = "UTC"))

  if (is.na(parsed)) {
    parsed <- suppressWarnings(as.POSIXct(x, tz = timezone_name))
  }

  if (is.na(parsed)) {
    stop("Could not parse REFRESH_GATE_NOW: ", x, call. = FALSE)
  }

  parsed
}

format_local <- function(x) {
  format(as.POSIXct(x, tz = timezone_name), tz = timezone_name, usetz = TRUE)
}

latest_fixture_schedule <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  raw <- readRDS(path)

  if (!is.data.frame(raw) || nrow(raw) == 0) {
    return(NULL)
  }

  ordering <- order(raw$run_ts, raw$round, raw$fixture_key, raw$team_abbrev)
  raw <- raw[ordering, , drop = FALSE]

  dedupe_key <- paste(raw$round, raw$fixture_key, raw$team_abbrev, sep = "::")
  latest <- raw[!duplicated(dedupe_key, fromLast = TRUE), , drop = FALSE]

  latest[latest$home_away %in% "home" &
           !(latest$bye_flag %in% TRUE) &
           !is.na(latest$kickoff_at_utc), , drop = FALSE]
}

now_utc <- parse_now(now_override)
now_local <- as.POSIXct(format(now_utc, tz = timezone_name, usetz = TRUE), tz = timezone_name)
today_local <- format(now_local, "%Y-%m-%d", tz = timezone_name)

should_run <- FALSE
reasons <- character()
matched_games <- character()

if (event_name %in% c("workflow_dispatch", "repository_dispatch", "manual")) {
  should_run <- TRUE
  reasons <- c(reasons, "manual_dispatch")
} else {
  for (daily_time in daily_times) {
    target_local <- suppressWarnings(as.POSIXct(paste(today_local, daily_time), tz = timezone_name))

    if (!is.na(target_local)) {
      delta_minutes <- abs(as.numeric(difftime(now_local, target_local, units = "mins")))

      if (delta_minutes <= daily_tolerance_minutes) {
        should_run <- TRUE
        reasons <- c(reasons, paste0("daily_refresh_", gsub(":", "", daily_time, fixed = TRUE)))
      }
    }
  }

  schedule_path <- file.path(
    "data",
    paste0("supercoach_league_", league_id),
    "nrl_fixture_source_history.rds"
  )

  schedule <- latest_fixture_schedule(schedule_path)

  if (is.null(schedule)) {
    should_run <- TRUE
    reasons <- c(reasons, "bootstrap_missing_nrl_schedule")
  } else {
    minutes_to_game <- as.numeric(difftime(schedule$kickoff_at_utc, now_utc, units = "mins"))

    for (threshold in pregame_minutes) {
      idx <- which(
        minutes_to_game >= (threshold - pregame_tolerance_minutes) &
          minutes_to_game <= (threshold + pregame_tolerance_minutes)
      )

      if (length(idx) > 0) {
        should_run <- TRUE
        reasons <- c(reasons, paste0("pregame_", threshold))

        labels <- paste(
          paste0("R", schedule$round[idx]),
          schedule$team_abbrev[idx],
          "v",
          schedule$opponent_abbrev[idx],
          "@",
          format_local(schedule$kickoff_at_utc[idx])
        )

        matched_games <- c(matched_games, labels)
      }
    }
  }
}

reasons <- unique(reasons)
matched_games <- unique(matched_games)

emit_output("should_run", tolower(as.character(should_run)))
emit_output("run_reason", if (length(reasons) == 0) "no_trigger_window" else paste(reasons, collapse = "|"))
emit_output("matched_games", if (length(matched_games) == 0) "none" else paste(matched_games, collapse = " | "))
emit_output("evaluated_at", format_local(now_utc))
