
#' Launch CDM Refresh Comparison Explorer
#'
#' Launches an interactive Shiny dashboard to explore
#' the results of an OMOP CDM refresh comparison.
#'
#' @param resultsFile Path to the CSV comparison results.
#'
#' @return Launches a Shiny application.
#'
#' @export
launchComparisonExplorer <- function(resultsFile, oldCdmName = "Old CDM", newCdmName = "New CDM") {

  # Check that the results file exists
  if (!file.exists(resultsFile)) {
    stop(
      "Results file not found: ",
      resultsFile
    )
  }
  # Convert to an absolute path
  resultsFile <- normalizePath(
    resultsFile,
    mustWork = TRUE
  )
  # Find the Shiny app inside the installed package
  appDir <- system.file(
    "shiny",
    package = "CDMRefreshCompare"
  )

  if (!nzchar(appDir)) {
    stop(
      "Shiny app not found in the installed package."
    )
  }

  # Make the results file available to the app
  options(
    CDMRefreshCompare.resultsFile = resultsFile,
    CDMRefreshCompare.oldCdmName = oldCdmName,
    CDMRefreshCompare.newCdmName = newCdmName

  )

  # Launch the application
  shiny::runApp(appDir)
}
