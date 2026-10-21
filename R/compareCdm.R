
#' Compare Two OMOP CDM Refreshes
#'
#' Runs the available comparison checks between
#' a previous and a refreshed OMOP CDM.
#'
#' @param con_old DBI connection to the old CDM.
#' @param con_new DBI connection to the new CDM.
#' @param schema_old Schema of the old CDM.
#' @param schema_new Schema of the new CDM.
#' @param tables Tables to compare.
#'
#' @return A list containing comparison results.
#'
#' @export
compareCdm <- function(
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

  counts <- compareCounts(
    con_old = con_old,
    con_new = con_new,
    schema_old = schema_old,
    schema_new = schema_new,
    tables = tables
  )

  list(
    counts = counts
  )
}
