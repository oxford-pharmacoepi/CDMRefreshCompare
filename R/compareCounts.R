
#' Compare Record Counts Between Two OMOP CDMs
#'
#' Compare table-level record counts across two CDM
#' database connections using OHDSI DatabaseConnector.
#'
#' @param con_old DatabaseConnector connection to the old CDM.
#' @param con_new DatabaseConnector connection to the new CDM.
#' @param schema_old Schema containing the old CDM.
#' @param schema_new Schema containing the new CDM.
#' @param tables Character vector of CDM table names.
#'
#' @return A data frame containing record counts,
#'   absolute differences and percentage changes.
#'
#' @export
compareCounts <- function(
    con_old,
    con_new,
    schema_old,
    schema_new,
    tables = c(
      "person",
      "condition_occurrence",
      "drug_exposure",
      "measurement",
      "visit_occurrence",
      "observation"
    )
) {

  # Validate schema and table names
  valid_name <- function(x) {
    is.character(x) &&
      length(x) == 1 &&
      !is.na(x) &&
      grepl("^[A-Za-z_][A-Za-z0-9_]*$", x)
  }

  valid_schema <- function(x) {
    is.character(x) &&
      length(x) == 1 &&
      !is.na(x) &&
      all(vapply(
        strsplit(x, ".", fixed = TRUE)[[1]],
        valid_name,
        logical(1)
      ))
  }

  if (!valid_schema(schema_old) ||
      !valid_schema(schema_new)) {
    stop("Invalid CDM schema name.")
  }

  if (length(tables) == 0 ||
      !all(vapply(tables, valid_name, logical(1)))) {
    stop("Invalid CDM table names.")
  }

  # Query record count using DatabaseConnector
  count_rows <- function(connection, schema, table) {

    # Create SQL query
    sql <- paste0(
      "SELECT COUNT(*) AS record_count FROM ",
      schema, ".", table
    )

    # Execute SQL using DatabaseConnector
    result <- DatabaseConnector::querySql(
      connection = connection,
      sql = sql
    )

    # Check the returned data
    if (nrow(result) != 1 || ncol(result) != 1) {
      stop(
        "Unexpected query result for table: ",
        table
      )
    }

    # Extract the first value regardless of column name
    count <- as.numeric(result[[1]][[1]])

    # Ensure the count is valid
    if (length(count) != 1 ||
        is.na(count) ||
        !is.finite(count)) {
      stop(
        "Invalid record count returned for table: ",
        table
      )
    }

    return(count)
  }

  # Compare each CDM table
  results <- lapply(tables, function(table) {

    old_count <- count_rows(
      con_old, schema_old, table
    )

    new_count <- count_rows(
      con_new, schema_new, table
    )

    difference <- new_count - old_count

    percent_change <- if (old_count == 0) {
      if (new_count == 0) 0 else NA_real_
    } else {
      (difference / old_count) * 100
    }

    data.frame(
      table = table,
      old_count = old_count,
      new_count = new_count,
      difference = difference,
      percent_change = round(percent_change, 2)
    )
  })

  do.call(rbind, results)
}


