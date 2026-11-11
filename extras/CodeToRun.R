# CDMRefreshCompare - extras/CodeToRun.R
# Run from the root of the CDMRefreshCompare RStudio project.
# IMPORTANT: This JDBC runner requires a DatabaseConnector-compatible
# compareCdm() implementation. The original DBI-based package functions
# must be migrated before running this script.

# INSTALL DEPENDENCIES --------------------------------------------------------
packages <- c("remotes", "devtools", "DatabaseConnector", "here" , "shiny" , "ggplot2" ,"DT")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing)

# Install the local package you are developing.
# To use the GitHub version instead, replace the next line with:
remotes::install_github("oxford-pharmacoepi/CDMRefreshCompare")
devtools::install(upgrade = "never")

# The same PostgreSQL JDBC driver can be used for both connections.
DatabaseConnector::downloadJdbcDrivers(
  dbms = "postgresql",
  pathToDriver = here::here()
)

library(CDMRefreshCompare)
library(DatabaseConnector)

# [*] EDIT BELOW -------------------------------------------------------------

# Connection to the PREVIOUS CDM
oldServer <- "host/database"
oldConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  user = "",
  password = "",
  server = oldServer,
  port = ,
  pathToDriver = here::here()
)
oldCdmDatabaseSchema <- ""

# Connection to the REFRESHED CDM
newServer <- "host/database"
newConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  user = "",
  password = "",
  server = newServer,
  port = ,
  pathToDriver = here::here()
)
newCdmDatabaseSchema <- ""

# Tables to compare
cdmTables <- c(
  "PERSON","OBSERVATION_PERIOD","VISIT_OCCURRENCE","VISIT_DETAIL","CONDITION_OCCURRENCE","DRUG_EXPOSURE","PROCEDURE_OCCURRENCE","DEVICE_EXPOSURE",
  "MEASUREMENT","OBSERVATION","DEATH","SPECIMEN","LOCATION","CARE_SITE","PROVIDER","DRUG_ERA","CONDITION_ERA","CONCEPT","VOCABULARY","CONCEPT_CLASS",
  "CONCEPT_RELATIONSHIP","RELATIONSHIP","CONCEPT_SYNONYM","CONCEPT_ANCESTOR","SOURCE_TO_CONCEPT_MAP","DRUG_STRENGTH"
)

# Folder for results
outputFolder <- here::here("comparison_results")

# [!] DO NOT EDIT BELOW ------------------------------------------------------


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


# Launch the CDM comparison dashboard

# Automatically extract CDM database names
oldCdmName <- sub("^.*/", "", oldServer)
newCdmName <- sub("^.*/", "", newServer)


CDMRefreshCompare::launchComparisonExplorer(
  resultsFile = file.path(
    outputFolder,
    "cdm_refresh_counts.csv"
  ),
  oldCdmName = oldCdmName,
  newCdmName = newCdmName
)
