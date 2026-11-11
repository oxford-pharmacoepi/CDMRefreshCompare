
# CDMRefreshCompare

### Compare, Explore, and Understand Your OMOP CDM Refreshes

**CDMRefreshCompare** is an R package designed to simplify the comparison of two versions of the **Observational Medical Outcomes Partnership Common Data Model (OMOP CDM)** following a source data refresh.

The package helps ETL developers, data engineers, and researchers identify changes in record counts across CDM tables and explore those differences through an interactive Shiny dashboard.

> **Note:** Changes in record counts do not necessarily indicate ETL errors. Differences may result from source data updates, corrections, or changes in data availability.

---

## Features

- **CDM-to-CDM comparison:** Compare two OMOP CDM instances.
- **Database connectivity:** Connect to PostgreSQL using OHDSI's `DatabaseConnector` and JDBC.
- **Table-level comparison:** Compare record counts across CDM tables.
- **Difference calculations:** Calculate absolute and percentage changes.
- **CDM and vocabulary filtering:** Separate clinical CDM tables from vocabulary tables.
- **Interactive Shiny dashboard:** Explore comparison results visually.
- **Hover functionality:** View detailed record counts and percentage changes.
- **Table drill-down:** Click individual tables to compare both CDMs side by side.
- **CSV export:** Download comparison results for further analysis.
- **Offline exploration:** Reopen saved results without reconnecting to the databases.

---

## Installation

### Prerequisites

Before using CDMRefreshCompare, ensure you have:

- R installed.
- RStudio installed (recommended).
- Access to two OMOP CDM databases.
- Database credentials with read permissions.
- A compatible Java environment for JDBC connections.

### Step 1: Clone the repository

Clone the GitHub repository:

```bash
git clone https://github.com/oxford-pharmacoepi/CDMRefreshCompare.git
```

Open the cloned project in RStudio.

### Step 2: Install dependencies

Run the following in the RStudio Console:

```r
install.packages(c(
  "devtools",
  "remotes",
  "here"
))
```

Install the dependencies declared by the package:

```r
devtools::install_deps(dependencies = TRUE)
```

### Step 3: Install CDMRefreshCompare

From the package project directory:

```r
devtools::install()
```

Alternatively, install directly from GitHub:

```r
remotes::install_github(
  "oxford-pharmacoepi/CDMRefreshCompare"
)
```

Load the package:

```r
library(CDMRefreshCompare)
```

---

## Configuration

The package includes a user-facing script located at:

```text
extras/CodeToRun.R
```

This script allows users to configure database connections, select tables, execute comparisons, and generate results.

### Step 1: Download the PostgreSQL JDBC driver

```r
DatabaseConnector::downloadJdbcDrivers(
  dbms = "postgresql",
  pathToDriver = here::here()
)
```

The JDBC driver is downloaded to the specified directory.

### Step 2: Configure the previous CDM

```r
oldServer <- "host/old_database"

oldConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  user = "YOUR_USERNAME",
  password = "YOUR_PASSWORD",
  server = oldServer,
  port = 5432,
  pathToDriver = here::here()
)

oldCdmDatabaseSchema <- "public"
```

Replace the placeholders with your actual database connection details.

### Step 3: Configure the refreshed CDM

```r
newServer <- "host/new_database"

newConnectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "postgresql",
  user = "YOUR_USERNAME",
  password = "YOUR_PASSWORD",
  server = newServer,
  port = 5432,
  pathToDriver = here::here()
)

newCdmDatabaseSchema <- "public"
```

Both CDMs can be located on different servers, in different databases, or in different schemas.

> **Security:** Never commit database credentials to GitHub. Keep locally configured scripts containing real passwords private.

---

## Selecting CDM Tables

Users can specify which tables to compare by modifying `tables_to_compare` in `extras/CodeToRun.R`.

For example:

```r
tables_to_compare <- c(
  "person",
  "condition_occurrence",
  "drug_exposure",
  "measurement",
  "visit_occurrence",
  "observation"
)
```

### Comparing Vocabulary Tables

To include OMOP vocabulary tables:

```r
tables_to_compare <- c(
  tables_to_compare,
  "concept",
  "vocabulary",
  "domain",
  "concept_class",
  "relationship",
  "concept_relationship",
  "concept_ancestor",
  "concept_synonym",
  "drug_strength"
)
```

The selected tables must exist in both CDM databases.

---

## Running CDMRefreshCompare

Once the database connection details have been configured, run:

```r
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
```

The script will:

1. Connect to the previous CDM.
2. Connect to the refreshed CDM.
3. Execute record-count comparisons.
4. Calculate absolute and percentage differences.
5. Save the comparison results.
6. Disconnect from the databases.

### Example Comparison Results

| CDM Table | Previous CDM | Refreshed CDM | Difference | Change (%) |
|-----------|-------------:|--------------:|-----------:|-----------:|
| PERSON | 125,000 | 132,500 | +7,500 | +6.00% |
| CONDITION_OCCURRENCE | 850,000 | 920,000 | +70,000 | +8.24% |
| DRUG_EXPOSURE | 1,200,000 | 1,260,000 | +60,000 | +5.00% |
| MEASUREMENT | 2,500,000 | 2,450,000 | -50,000 | -2.00% |
| VISIT_OCCURRENCE | 430,000 | 455,000 | +25,000 | +5.81% |

*The values above are illustrative.*

### Output Files

The comparison results are saved to:

```text
comparison_results/
└── cdm_refresh_counts.csv
```

The CSV contains the following columns:

| Column | Description |
|--------|-------------|
| `table` | OMOP CDM table name |
| `old_count` | Record count in the previous CDM |
| `new_count` | Record count in the refreshed CDM |
| `difference` | Absolute difference in record counts |
| `percent_change` | Percentage change between CDMs |

---

## Interactive Shiny Dashboard

CDMRefreshCompare includes an interactive Shiny application for exploring comparison results.

### Launching the Dashboard

```r
oldCdmName <- sub("^.*/", "", oldServer)
newCdmName <- sub("^.*/", "", newServer)

CDMRefreshCompare::launchComparisonExplorer(
  resultsFile = here::here(
    "comparison_results",
    "cdm_refresh_counts.csv"
  ),
  oldCdmName = "old_database",
  newCdmName = "new_database"
)
```

Replace the example database names with your actual CDM names.

### Dashboard Features

#### 1. CDM Summary

The dashboard displays:

- Previous CDM name and total records.
- Refreshed CDM name and total records.
- Overall percentage change.

These totals represent records across the selected tables, not unique patients.

#### 2. Table Category Filtering

Users can filter results by:

- All tables.
- CDM tables.
- Vocabulary tables.

Individual tables can also be selected.

#### 3. Interactive Charts

The dashboard provides an interactive Plotly chart showing percentage changes across CDM tables.

Hovering over a bar displays:

- Table name.
- Previous CDM record count.
- Refreshed CDM record count.
- Absolute difference.
- Percentage change.

#### 4. Table Drill-Down

Clicking a table opens a detailed comparison showing:

- Previous CDM record count.
- Refreshed CDM record count.
- Side-by-side comparison chart.
- Absolute difference.
- Percentage change.

#### 5. Export Results

Users can download filtered comparison results as CSV files.

### Viewing Saved Results

The Shiny dashboard reads saved comparison results.

Once a comparison has been completed, users can reopen the dashboard without reconnecting to the databases.

---

## Interpreting Comparison Results

CDMRefreshCompare identifies and quantifies changes between two OMOP CDM refreshes.

A positive percentage indicates an increase in record counts.

A negative percentage indicates a decrease in record counts.

A zero percentage indicates no net change in record counts.

**These changes do not necessarily represent ETL errors.**

For example:

- An increase in condition records may reflect newly available clinical data.
- A decrease in measurement records may result from source corrections.
- An increase in person records may reflect newly registered patients.
- Changes in vocabulary tables may reflect updated OMOP vocabulary releases.

Identical record counts do not guarantee that the underlying records are identical.

CDMRefreshCompare is intended to support investigation and validation rather than automatically classify differences as errors.

---

## Troubleshooting

### Results File Not Found

Verify that the comparison CSV exists:

```r
file.exists(
  here::here(
    "comparison_results",
    "cdm_refresh_counts.csv"
  )
)
```

If the file does not exist, rerun the comparison.

### Shiny Function Not Exported

If you receive:

```text
'launchComparisonExplorer' is not an exported object
```

Run:

```r
devtools::document()
devtools::install()
```

Restart R and reload the package.

### Corrupted Package Installation

If R reports a corrupted lazy-load database, close the Shiny application, restart R, and reinstall:

```r
remove.packages("CDMRefreshCompare")

devtools::install()
```

### Vocabulary Tables Not Displayed

Ensure vocabulary tables have been included in `tables_to_compare`.

Rerun the comparison to generate results for those tables.

---

## Development

CDMRefreshCompare is under active development.

To contribute, clone the repository and open the project in RStudio.

After making changes, run:

```r
devtools::document()
devtools::test()
devtools::check()
```

These commands regenerate documentation, execute automated tests, and check the package.

---

## Planned Features

Future development may include:

- Parallel processing to improve comparison performance.
- Historical record comparisons by year and month.
- Patient population and demographic comparisons.
- Clinical concept frequency comparisons.
- Data quality comparisons.
- Record-level reconciliation.
- Enhanced reporting and comparison history.
- Configurable thresholds for identifying changes requiring investigation.

---

## Contributing

Contributions, feature suggestions, and bug reports are welcome.

Please use the GitHub repository to report issues or propose improvements:

https://github.com/oxford-pharmacoepi/CDMRefreshCompare/issues

---

## License

See the `LICENSE` file in the repository for licensing information.
