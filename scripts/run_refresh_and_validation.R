suppressPackageStartupMessages({
  library(knitr)
})

message("SuperCoach refresh + validation starting...")

if (!nzchar(Sys.getenv("SC_BEARER"))) {
  stop("SC_BEARER is not set. Export it in this terminal before running this script.")
}

prod_input <- "Jerky Turkey's league info pull and tracking.Rmd"
prod_output <- "Jerky Turkey's league info pull and tracking.md"
validation_input <- "supercoach_data_validation_report.Rmd"
validation_output <- "supercoach_data_validation_report.md"

message("1/2 Refreshing production data from ", prod_input)
knit(input = prod_input, output = prod_output, quiet = FALSE)

message("2/2 Building validation guide from ", validation_input)
knit(input = validation_input, output = validation_output, quiet = FALSE)

message("Done.")
message("Open: ", normalizePath(validation_output))
