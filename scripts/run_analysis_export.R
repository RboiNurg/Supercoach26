league_id <- suppressWarnings(as.integer(Sys.getenv("SC_LEAGUE_ID", "21064")))
data_dir <- file.path("data", paste0("supercoach_league_", league_id))
build_script <- "scripts/build_gpt_prompt_pack.R"
rmd_path <- "Jerky Turkey's league info pull and tracking.Rmd"
md_path <- sub("\\.Rmd$", ".md", rmd_path)
refresh_first <- tolower(Sys.getenv("EXPORT_REFRESH_FIRST", "true")) %in% c("true", "1", "yes")

required_packages <- c("dplyr", "tidyr", "jsonlite")
if (refresh_first) {
  required_packages <- c(required_packages, "knitr")
}

missing_packages <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages) > 0) {
  stop(
    "Missing required package(s): ",
    paste(missing_packages, collapse = ", "),
    call. = FALSE
  )
}

if (refresh_first) {
  if (!nzchar(Sys.getenv("SC_BEARER"))) {
    stop("SC_BEARER must be set when EXPORT_REFRESH_FIRST=true.", call. = FALSE)
  }

  knitr::knit(rmd_path, quiet = TRUE)

  if (file.exists(md_path)) {
    unlink(md_path)
  }
}

source(build_script, local = TRUE)
result <- build_gpt_prompt_pack(data_dir = data_dir, league_id = league_id)

meta <- jsonlite::read_json(result$metadata_path)
print(meta)
