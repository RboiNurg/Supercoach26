suppressPackageStartupMessages({
  library(rsconnect)
  library(jsonlite)
})

league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_prefix <- file.path("data", paste0("supercoach_league_", league_id))

data_files <- c(
  "game_rules_round_state.rds",
  "ladder_history.rds",
  "fixtures_history.rds",
  "structure_health_table.rds",
  "opponent_behaviour_history.rds",
  "fixture_matchup_table.rds",
  "team_performance_context.rds",
  "source_refresh_log.rds",
  "team_round_stats_history.rds",
  "players_cf_latest.rds",
  "team_players_latest.rds",
  "availability_risk_table.rds",
  "squad_round_enriched.rds",
  "cash_generation_model.rds",
  "master_player_round_latest.rds",
  "checklist_coverage_status.rds",
  "long_horizon_planning_table.rds",
  file.path("analysis_export", "latest_gpt_prompt_pack.md"),
  file.path("analysis_export", "latest_gpt_prompt_pack.txt"),
  file.path("analysis_export", "latest_gpt_prompt_pack_meta.json"),
  file.path("manual_inputs", "origin_watch.csv"),
  file.path("manual_inputs", "weekly_context_notes.md")
)

app_files <- c(
  "app.R",
  "Purpose and Strategy.md",
  "scripts/build_gpt_prompt_pack.R",
  file.path(data_prefix, data_files)
)

missing_files <- app_files[!file.exists(app_files)]
if (length(missing_files) > 0) {
  stop(
    "Cannot write manifest because these files are missing:\n",
    paste(missing_files, collapse = "\n"),
    call. = FALSE
  )
}

writeManifest(
  appDir = ".",
  appFiles = app_files,
  appPrimaryDoc = "app.R"
)

manifest <- read_json("manifest.json", simplifyVector = FALSE)

drop_packages <- c(
  "backports",
  "callr",
  "desc",
  "evaluate",
  "googledrive",
  "pkgbuild",
  "pkgload",
  "praise",
  "processx",
  "ps",
  "rprojroot",
  "testthat",
  "xtable"
)

manifest$packages[drop_packages] <- NULL

cran_db <- available.packages(repos = "https://cloud.r-project.org")

for (pkg in c("isoband", "xtable")) {
  if (pkg %in% rownames(cran_db)) {
    fields <- colnames(cran_db)
    fields <- fields[fields != "Package"]

    pkg_desc <- list(Package = pkg)
    for (field in fields) {
      value <- cran_db[pkg, field]
      if (!is.na(value) && nzchar(value)) {
        pkg_desc[[field]] <- value
      }
    }

    manifest$packages[[pkg]] <- list(
      Source = "CRAN",
      Repository = "https://cloud.r-project.org",
      description = pkg_desc
    )
  }
}

write_json(
  manifest,
  "manifest.json",
  auto_unbox = TRUE,
  pretty = TRUE,
  null = "null"
)

cat("manifest.json written for Connect Cloud deployment.\n")
