args <- commandArgs(trailingOnly = TRUE)

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_dir <- file.path("data", paste0("supercoach_league_", league_id))
rmd_path <- "Jerky Turkey's league info pull and tracking.Rmd"
md_path <- sub("\\.Rmd$", ".md", rmd_path)

required_packages <- c("knitr")
missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (length(missing_packages) > 0) {
  stop(
    "Missing required package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

if (!nzchar(Sys.getenv("SC_BEARER"))) {
  stop("SC_BEARER must be set before running the refresh pipeline.", call. = FALSE)
}

if (!file.exists(rmd_path)) {
  stop("Could not find Rmd: ", rmd_path, call. = FALSE)
}

knitr::knit(rmd_path, quiet = TRUE)

if (file.exists(md_path)) {
  unlink(md_path)
}

summary_targets <- c(
  game_rules_round_state = "game_rules_round_state.rds",
  master_player_round_latest = "master_player_round_latest.rds",
  player_scoring_component_history = "player_scoring_component_history.rds",
  team_list_role_certainty = "team_list_role_certainty.rds",
  fixture_matchup_table = "fixture_matchup_table.rds",
  team_performance_context = "team_performance_context.rds",
  cash_generation_model = "cash_generation_model.rds",
  squad_round_enriched = "squad_round_enriched.rds",
  opponent_behaviour_history = "opponent_behaviour_history.rds",
  availability_risk_table = "availability_risk_table.rds",
  structure_health_table = "structure_health_table.rds",
  long_horizon_planning_table = "long_horizon_planning_table.rds"
)

row_count <- function(path) {
  if (!file.exists(path)) {
    return(NA_integer_)
  }

  obj <- readRDS(path)

  if (is.data.frame(obj)) {
    return(nrow(obj))
  }

  length(obj)
}

counts <- data.frame(
  table_name = names(summary_targets),
  row_count = vapply(file.path(data_dir, unname(summary_targets)), row_count, integer(1)),
  stringsAsFactors = FALSE
)

print(counts, row.names = FALSE)

coverage_path <- file.path(data_dir, "checklist_coverage_status.rds")

if (file.exists(coverage_path)) {
  coverage <- readRDS(coverage_path)
  print(coverage[, c("checklist_item", "status", "notes")], row.names = FALSE)
}
