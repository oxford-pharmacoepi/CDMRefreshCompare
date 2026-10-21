
#' Compare Record Counts Between Two OMOP CDMs
#'
#' Compares the number of records in selected tables
#' across two CDM database connections.
#'
#' @param con_old A DBI connection to the previous CDM.
#' @param con_new A DBI connection to the refreshed CDM.
#' @param schema_old Schema containing the previous CDM.
#' @param schema_new Schema containing the refreshed CDM.
#' @param tables Character vector of CDM table names.
#'
#' @return A data.frame with old and new record counts,
#'   absolute differences, and percentage changes.
#'
#' @export
compareCounts <- function(
    con_old,
    con_new,
    schema_old = NULL,
    schema_new = NULL,
    tables = c(
      "person",
      "condition_occurrence",
      "drug_exposure",
      "measurement",
      "visit_occurrence",
      "observation"
    )
) {

  # Helper function: count rows in one table
  count_rows <- function(con, schema, table) {

    # Build a safe database table identifier
    table_id <- if (is.null(schema)) {
      table
    } else {
      DBI::Id(schema = schema, table = table)
    }

    # Stop if the table cannot be found
    if (!DBI::dbExistsTable(con, table_id)) {
      stop("Table not found: ", table)
    }

    # Quote the identifier for the database
    quoted_table <- DBI::dbQuoteIdentifier(
      con, table_id
    )

    # Execute COUNT(*) inside the database
    sql <- paste0(
      "SELECT COUNT(*) AS n FROM ",
      as.character(quoted_table)
    )

    result <- DBI::dbGetQuery(con, sql)

    as.numeric(result$n[[1]])
  }

  # Compare every requested table
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
      percent_change = round(
        percent_change, 2
      )
    )
  })

  # Combine individual results
  do.call(rbind, results)
}
