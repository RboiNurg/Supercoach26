#!/usr/bin/env Rscript

suppressPackageStartupMessages({
  library(jsonlite)
  library(dplyr)
  library(tibble)
  library(purrr)
  library(stringr)
})

`%||%` <- function(a, b) {
  if (is.null(a) || length(a) == 0) b else a
}

stop_if_missing <- function(var_name) {
  value <- Sys.getenv(var_name, unset = "")
  if (!nzchar(value)) {
    stop(sprintf("Environment variable %s must be set", var_name), call. = FALSE)
  }
  value
}

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", unset = "21064")))
if (is.na(league_id)) league_id <- 21064L

base_url <- "https://www.supercoach.com.au/2026/api/nrl/classic/v1"
probe_ts <- format(Sys.time(), "%Y%m%dT%H%M%S")
sc_bearer <- stop_if_missing("SC_BEARER")

data_dir <- file.path("data", paste0("supercoach_league_", league_id), "probe")
raw_dir <- file.path(data_dir, "raw")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)

build_url <- function(base, query = list()) {
  query <- query[!vapply(query, is.null, logical(1))]
  if (length(query) == 0) {
    return(base)
  }

  encoded <- purrr::imap_chr(
    query,
    ~ paste0(
      utils::URLencode(.y, reserved = TRUE),
      "=",
      utils::URLencode(as.character(.x), reserved = TRUE)
    )
  )

  paste0(base, "?", paste(encoded, collapse = "&"))
}

run_curl_probe <- function(url, auth_required = TRUE) {
  body_file <- tempfile("probe_body_")
  header_file <- tempfile("probe_header_")
  on.exit(unlink(c(body_file, header_file), force = TRUE), add = TRUE)

  args <- c(
    "-sS",
    "-D", header_file,
    "-o", body_file,
    "-w", "%{http_code}",
    "-H", "User-Agent: Mozilla/5.0",
    "-H", "Accept: application/json"
  )

  if (auth_required) {
    args <- c(
      args,
      "-H", paste("Authorization: Bearer", sc_bearer),
      "-H", sprintf(
        "Referer: https://www.supercoach.com.au/nrl/classic/leagues(popup:leagues/%s/head-2-head)",
        league_id
      ),
      "-H", "Origin: https://www.supercoach.com.au"
    )
  }

  args <- c(args, url)
  command <- paste("curl", paste(shQuote(args), collapse = " "))
  status_raw <- tryCatch(
    suppressWarnings(system(command, intern = TRUE)),
    error = function(e) paste("curl-error", conditionMessage(e))
  )

  status_code <- suppressWarnings(as.integer(tail(status_raw, 1)))
  body_text <- if (file.exists(body_file)) paste(readLines(body_file, warn = FALSE), collapse = "\n") else ""
  list(
    status_code = status_code %||% NA_integer_,
    body_text = body_text
  )
}

parse_json_loose <- function(text) {
  tryCatch(fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
}

redact_sensitive_text <- function(text) {
  text %>%
    str_replace_all('"email":"[^"]*"', '"email":"<redacted>"') %>%
    str_replace_all('"phone":"[^"]*"', '"phone":"<redacted>"') %>%
    str_replace_all('"postcode":"[^"]*"', '"postcode":"<redacted>"') %>%
    str_replace_all('"think_id":"[^"]*"', '"think_id":"<redacted>"')
}

collect_paths <- function(x, prefix = "", depth = 0, max_depth = 3) {
  if (is.null(x) || depth > max_depth) {
    return(character())
  }

  if (!is.list(x)) {
    return(prefix)
  }

  nm <- names(x)
  if (is.null(nm) || all(nm == "")) {
    if (length(x) == 0) {
      return(prefix)
    }
    marker <- if (nzchar(prefix)) paste0(prefix, "[]") else "[]"
    return(c(marker, collect_paths(x[[1]], marker, depth + 1, max_depth)))
  }

  out <- character()
  for (child_name in nm) {
    child_prefix <- if (nzchar(prefix)) paste(prefix, child_name, sep = ".") else child_name
    out <- c(out, child_prefix, collect_paths(x[[child_name]], child_prefix, depth + 1, max_depth))
  }

  unique(out)
}

schema_summary <- function(body_text) {
  parsed <- parse_json_loose(body_text)
  if (is.null(parsed)) {
    return(list(
      schema_summary = paste0("non-json body, ", nchar(body_text), " bytes"),
      key_fields = NA_character_
    ))
  }

  paths <- collect_paths(parsed)
  top_level <- if (is.list(parsed)) paste(names(parsed) %||% character(), collapse = ", ") else class(parsed)[1]
  list(
    schema_summary = paste0("top-level: ", top_level),
    key_fields = paste(head(paths[nzchar(paths)], 12), collapse = "; ")
  )
}

fetch_settings <- function() {
  url <- build_url(paste0(base_url, "/settings"))
  out <- run_curl_probe(url, auth_required = TRUE)
  parsed <- parse_json_loose(out$body_text)
  if (is.null(parsed)) {
    stop("Unable to parse /settings response")
  }
  parsed
}

settings <- fetch_settings()
current_round <- settings$competition$current_round %||% 1L
next_round <- settings$competition$next_round %||% (current_round + 1L)

fetch_my_team_id <- function(round_value) {
  url <- build_url(
    paste0(base_url, "/leagues/", league_id, "/ladderAndFixtures"),
    list(round = round_value)
  )
  out <- run_curl_probe(url, auth_required = TRUE)
  parsed <- parse_json_loose(out$body_text)
  ladder_rows <- parsed$ladder %||% list()
  my_row <- keep(ladder_rows, ~ isTRUE(.x$userTeam$user$is_me %||% FALSE))
  if (length(my_row) == 0) {
    return(NA_integer_)
  }
  as.integer(my_row[[1]]$user_team_id %||% NA_integer_)
}

my_team_id <- fetch_my_team_id(current_round)
sample_team_id <- my_team_id

probe_specs <- list(
  list(name = "settings", endpoint = "/settings", params = list(), auth_required = TRUE),
  list(name = "me", endpoint = "/me", params = list(), auth_required = TRUE),
  list(name = "teams", endpoint = "/teams", params = list(), auth_required = TRUE),
  list(name = "players_cf", endpoint = "/players-cf", params = list(), auth_required = TRUE),
  list(name = "players_cf_round_current", endpoint = "/players-cf", params = list(round = current_round), auth_required = TRUE),
  list(name = "players_cf_round_next", endpoint = "/players-cf", params = list(round = next_round), auth_required = TRUE),
  list(
    name = "ladder_and_fixtures_current",
    endpoint = sprintf("/leagues/%s/ladderAndFixtures", league_id),
    params = list(round = current_round),
    auth_required = TRUE
  ),
  list(
    name = "ladder_and_fixtures_next",
    endpoint = sprintf("/leagues/%s/ladderAndFixtures", league_id),
    params = list(round = next_round),
    auth_required = TRUE
  ),
  list(
    name = "stats_players_current",
    endpoint = sprintf("/userteams/%s/statsPlayers", sample_team_id),
    params = list(round = current_round),
    auth_required = TRUE
  ),
  list(
    name = "stats_players_next",
    endpoint = sprintf("/userteams/%s/statsPlayers", sample_team_id),
    params = list(round = next_round),
    auth_required = TRUE
  ),
  list(
    name = "stats_initialvalue_sample",
    endpoint = "https://www.nrlsupercoachstats.com/initialvalue.php",
    params = list(year = 2026, grid_id = "list1", jqgrid_page = 1, rows = 20, search = "false"),
    auth_required = FALSE
  ),
  list(
    name = "stats_initialvalue_full",
    endpoint = "https://www.nrlsupercoachstats.com/initialvalue.php",
    params = list(year = 2026, grid_id = "list1", jqgrid_page = 1, rows = 2000, search = "false"),
    auth_required = FALSE
  ),
  list(
    name = "stats_yearplot_sample",
    endpoint = "https://www.nrlsupercoachstats.com/highcharts/data-yearplot.php",
    params = list(dropdown1 = "Cleary, Nathan", YEAR = 2026),
    auth_required = FALSE
  )
)

endpoint_map <- purrr::map_dfr(probe_specs, function(spec) {
  full_url <- if (startsWith(spec$endpoint, "http")) {
    build_url(spec$endpoint, spec$params)
  } else {
    build_url(paste0(base_url, spec$endpoint), spec$params)
  }

  result <- run_curl_probe(full_url, auth_required = spec$auth_required)
  schema <- schema_summary(result$body_text)
  redacted_body <- redact_sensitive_text(result$body_text)

  payload_path <- file.path(raw_dir, paste0(spec$name, "_", probe_ts, ".json"))
  writeLines(redacted_body, payload_path)

  production_ready <- ifelse(
    isTRUE(result$status_code == 200L),
    ifelse(spec$name %in% c(
      "settings",
      "me",
      "teams",
      "players_cf",
      "players_cf_round_current",
      "ladder_and_fixtures_current",
      "stats_players_current",
      "stats_initialvalue_full",
      "stats_yearplot_sample"
    ), "yes", "no"),
    "no"
  )

  tibble(
    endpoint = if (startsWith(spec$endpoint, "http")) spec$endpoint else paste0(base_url, spec$endpoint),
    params = jsonlite::toJSON(spec$params, auto_unbox = TRUE, null = "null"),
    auth_required = ifelse(spec$auth_required, "yes", "no"),
    status = as.character(result$status_code %||% NA_integer_),
    schema_summary = schema$schema_summary,
    key_fields = schema$key_fields,
    production_ready = production_ready,
    raw_payload_file = payload_path
  )
})

endpoint_map_path <- file.path(data_dir, "endpoint_map.csv")
write.csv(endpoint_map, endpoint_map_path, row.names = FALSE, na = "")

message("Wrote ", endpoint_map_path)
