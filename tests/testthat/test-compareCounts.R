
test_that("compareCounts calculates differences", {

  con_old <- DBI::dbConnect(
    RSQLite::SQLite(), ":memory:"
  )

  con_new <- DBI::dbConnect(
    RSQLite::SQLite(), ":memory:"
  )

  on.exit({
    DBI::dbDisconnect(con_old)
    DBI::dbDisconnect(con_new)
  }, add = TRUE)

  # Old database has 100 people
  DBI::dbWriteTable(
    con_old,
    "person",
    data.frame(id = seq_len(100))
  )

  # New database has 120 people
  DBI::dbWriteTable(
    con_new,
    "person",
    data.frame(id = seq_len(120))
  )

  result <- compareCounts(
    con_old,
    con_new,
    tables = "person"
  )

  expect_equal(result$old_count, 100)
  expect_equal(result$new_count, 120)
  expect_equal(result$difference, 20)
  expect_equal(result$percent_change, 20)
})
