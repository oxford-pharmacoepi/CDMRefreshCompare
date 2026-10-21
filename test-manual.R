
library(DBI)
library(RSQLite)

# Load the package we are developing
devtools::load_all()

# Create two temporary SQLite databases
con_old <- dbConnect(
  SQLite(), ":memory:"
)

con_new <- dbConnect(
  SQLite(), ":memory:"
)

# Define the tables we want to test
tables <- c(
  "person",
  "condition_occurrence",
  "drug_exposure",
  "measurement",
  "visit_occurrence",
  "observation"
)

# Define the number of records in each table
old_counts <- c(100, 200, 300, 400, 150, 80)
new_counts <- c(110, 250, 320, 380, 160, 90)

# Create the fake tables
for (i in seq_along(tables)) {

  dbWriteTable(
    con_old,
    tables[i],
    data.frame(
      record_id = seq_len(old_counts[i])
    )
  )

  dbWriteTable(
    con_new,
    tables[i],
    data.frame(
      record_id = seq_len(new_counts[i])
    )
  )
}

# Compare the two databases
results <- compareCounts(
  con_old = con_old,
  con_new = con_new
)

# Display the results
print(results)

# Disconnect when finished
dbDisconnect(con_old)
dbDisconnect(con_new)
