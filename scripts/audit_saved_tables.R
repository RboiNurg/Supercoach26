league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_dir <- file.path("data", paste0("supercoach_league_", league_id))

if (!dir.exists(data_dir)) {
  stop("Data directory does not exist: ", data_dir, call. = FALSE)
}

rds_paths <- list.files(data_dir, pattern = "\\.rds$", full.names = TRUE)

if (length(rds_paths) == 0) {
  stop("No .rds files found in ", data_dir, call. = FALSE)
}

safe_nrow <- function(x) {
  if (is.data.frame(x)) nrow(x) else length(x)
}

safe_ncol <- function(x) {
  if (is.data.frame(x)) ncol(x) else NA_integer_
}

latest_ts <- function(x) {
  if (!is.data.frame(x)) {
    return(NA_character_)
  }

  ts_cols <- intersect(
    c("run_ts", "detected_run_ts", "sent_at", "round_closed_through_utc", "kickoff_at_utc"),
    names(x)
  )

  if (length(ts_cols) == 0) {
    return(NA_character_)
  }

  parse_one <- function(value) {
    if (inherits(value, c("POSIXct", "POSIXt"))) {
      return(as.POSIXct(value, tz = "UTC"))
    }

    if (inherits(value, "Date")) {
      return(as.POSIXct(value, tz = "UTC"))
    }

    if (is.numeric(value)) {
      return(as.POSIXct(value, origin = "1970-01-01", tz = "UTC"))
    }

    suppressWarnings(as.POSIXct(as.character(value), tz = "UTC"))
  }

  preferred_cols <- intersect(c("run_ts", "detected_run_ts", "sent_at"), ts_cols)
  active_cols <- if (length(preferred_cols) > 0) preferred_cols else ts_cols

  values <- unlist(lapply(x[active_cols], function(col) lapply(col, parse_one)), recursive = FALSE)
  values <- as.POSIXct(unlist(values), origin = "1970-01-01", tz = "UTC")
  values <- values[!is.na(values)]

  if (length(values) == 0) {
    return(NA_character_)
  }

  format(max(values), tz = "Australia/Sydney", usetz = TRUE)
}

summary_tbl <- do.call(
  rbind,
  lapply(rds_paths, function(path) {
    obj <- readRDS(path)
    data.frame(
      file = basename(path),
      rows = safe_nrow(obj),
      cols = safe_ncol(obj),
      latest_timestamp = latest_ts(obj),
      stringsAsFactors = FALSE
    )
  })
)

summary_tbl <- summary_tbl[order(summary_tbl$file), ]
print(summary_tbl, row.names = FALSE)
