
#' Compare Two OMOP CDM Refreshes
#'
#' Run table-level comparisons between an old and a
#' refreshed OMOP CDM using DatabaseConnector.
#'
#' @param con_old Connection to the old CDM.
#' @param con_new Connection to the refreshed CDM.
#' @param schema_old Schema of the old CDM.
#' @param schema_new Schema of the new CDM.
#' @param tables Character vector of tables to compare.
#'
#' @return A list containing comparison results.
#'
#' @export
compareCdm <- function(
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

  message("Starting CDM refresh comparison...")

  counts <- compareCounts(
    con_old = con_old,
    con_new = con_new,
    schema_old = schema_old,
    schema_new = schema_new,
    tables = tables
  )

  message("CDM refresh comparison completed.")

  return(list(
    counts = counts
  ))
}
