# CDMRefreshCompare - extras/CodeToRun.R
# Run from the root of the CDMRefreshCompare RStudio project.
# IMPORTANT: This JDBC runner requires a DatabaseConnector-compatible
# compareCdm() implementation. The original DBI-based package functions
# must be migrated before running this script.

# INSTALL DEPENDENCIES --------------------------------------------------------
packages <- c("remotes", "devtools", "DatabaseConnector", "here")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing)

# Install the local package you are developing.
# To use the GitHub version instead, replace the next line with:
remotes::install_github("oxford-pharmacoepi/CDMRefreshCompare")
devtools::install(upgrade = "never")

library(CDMRefreshCompare)
library(DatabaseConnector)

# [*] EDIT BELOW -------------------------------------------------------------

# Connection to the PREVIOUS CDM
oldConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  user = "",
  password = "",
  server = "host/database",
  port = ,
  pathToDriver = here::here()
)
oldCdmDatabaseSchema <- ""

# Connection to the REFRESHED CDM
newConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  user = "",
  password = "",
  server = "host/database",
  port = ,
  pathToDriver = here::here()
)
newCdmDatabaseSchema <- ""

# Tables to compare
cdmTables <- c(
  "person", "condition_occurrence", "drug_exposure",
  "measurement", "visit_occurrence", "observation"
)

# Folder for results
outputFolder <- here::here("comparison_results")

# [!] DO NOT EDIT BELOW ------------------------------------------------------

# The same PostgreSQL JDBC driver can be used for both connections.
DatabaseConnector::downloadJdbcDrivers(
  dbms = "postgresql",
  pathToDriver = here::here()
)


oldConnection <- NULL
newConnection <- NULL

tryCatch({
  oldConnection <- DatabaseConnector::connect(oldConnectionDetails)
  newConnection <- DatabaseConnector::connect(newConnectionDetails)

  comparison <- CDMRefreshCompare::compareCdm(
    con_old = oldConnection,
    con_new = newConnection,
    schema_old = oldCdmDatabaseSchema,
    schema_new = newCdmDatabaseSchema,
    tables = cdmTables
  )

  if (!is.list(comparison) || !is.data.frame(comparison$counts)) {
    stop("Expected compareCdm() to return a list containing $counts.")
  }

  dir.create(outputFolder, recursive = TRUE, showWarnings = FALSE)
  outputFile <- file.path(outputFolder, "cdm_refresh_counts.csv")
  write.csv(comparison$counts, outputFile, row.names = FALSE)
  print(comparison$counts)
  message("Results saved to: ", normalizePath(outputFile))
}, error = function(e) {
  message("CDM comparison failed: ", conditionMessage(e))
  stop(e)
}, finally = {
  if (!is.null(newConnection)) DatabaseConnector::disconnect(newConnection)
  if (!is.null(oldConnection)) DatabaseConnector::disconnect(oldConnection)
})
