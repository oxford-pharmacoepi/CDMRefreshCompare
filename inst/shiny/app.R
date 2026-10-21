library(shiny)
library(ggplot2)
library(DT)

oldCdmName <- getOption(
  "CDMRefreshCompare.oldCdmName",
  "Old CDM"
)

newCdmName <- getOption(
  "CDMRefreshCompare.newCdmName",
  "New CDM"
)

# Get the CSV path passed by launchComparisonExplorer()
result_file <- getOption(
  "CDMRefreshCompare.resultsFile",
  default = NULL
)

# Make sure a results path was provided
if (is.null(result_file)) {
  stop(
    "No results file provided. ",
    "Please launch the dashboard using ",
    "CDMRefreshCompare::launchComparisonExplorer()."
  )
}

# Convert to an absolute path
result_file <- normalizePath(
  result_file,
  mustWork = TRUE
)

read_results <- function(path) {
  validate(need(file.exists(path), paste("Results file not found:", path)))
  x <- tryCatch(read.csv(path, stringsAsFactors = FALSE), error = function(e) NULL)
  validate(need(!is.null(x), "Unable to read the results CSV."))
  required <- c("table", "old_count", "new_count", "difference", "percent_change")
  validate(need(all(required %in% names(x)), paste("CSV must contain:", paste(required, collapse = ", "))))
  for (nm in required[-1]) x[[nm]] <- suppressWarnings(as.numeric(x[[nm]]))
  validate(need(!anyNA(x[, c("old_count", "new_count", "difference")]), "Invalid numeric counts in CSV."))
  x
}

ui <- fluidPage(
  titlePanel("CDMRefreshCompare | Refresh dashboard"),
  sidebarLayout(
    sidebarPanel(
      textInput("file", "Comparison CSV path", value = result_file),
      actionButton("reload", "Load results"),
      hr(),
      selectInput("tables", "Tables to display", choices = NULL, multiple = TRUE),
      downloadButton("download", "Download filtered CSV"),
      helpText("The dashboard reads saved aggregate results. No database connection is needed.")
    ),
    mainPanel(
      fluidRow(
        column(
          4,
          wellPanel(
            h4(oldCdmName),
            h3(textOutput("old_total", inline = TRUE)),
            p("Total records")
          )
        ),
        column(
          4,
          wellPanel(
            h4(newCdmName),
            h3(textOutput("new_total", inline = TRUE)),
            p("Total records")
          )
        ),
        column(
          4,
          wellPanel(
            h4("Overall change"),
            h3(textOutput("delta", inline = TRUE)),
            p("Percentage change")
          )
        )
      ),
      h3("Change by CDM table"),
      plotOutput("changes", height = "350px"),
      h3("Comparison details"),
      DTOutput("comparison"),
      p("A change in record counts does not necessarily indicate an ETL error.")
    )
  )
)

server <- function(input, output, session) {
  results <- eventReactive(input$reload, read_results(input$file), ignoreNULL = FALSE)
  observeEvent(results(), {
    tbl <- results()$table
    updateSelectInput(session, "tables", choices = tbl, selected = tbl)
  })
  filtered <- reactive({
    x <- results()
    req(input$tables)
    x[x$table %in% input$tables, , drop = FALSE]
  })
  output$old_total <- renderText(format(sum(filtered()$old_count), big.mark = ",", scientific = FALSE))
  output$new_total <- renderText(format(sum(filtered()$new_count), big.mark = ",", scientific = FALSE))
  output$delta <- renderText({
    x <- filtered()
    old <- sum(x$old_count)
    if (old == 0) return("N/A")
    sprintf("%+.2f%%", 100 * (sum(x$new_count) - old) / old)
  })
  output$changes <- renderPlot({
    x <- filtered()
    validate(need(nrow(x) > 0, "Select at least one table."))
    ggplot(x, aes(x = reorder(table, percent_change), y = percent_change)) +
      geom_col(fill = "#2376a5", na.rm = TRUE) + coord_flip() +
      labs(x = "CDM table", y = "Change (%)") + theme_minimal(base_size = 12)
  })
  output$comparison <- renderDT({
    datatable(filtered(), rownames = FALSE, options = list(pageLength = 10, scrollX = TRUE), filter = "top")
  })
  output$download <- downloadHandler(
    filename = function() paste0("cdm_comparison_", Sys.Date(), ".csv"),
    content = function(file) write.csv(filtered(), file, row.names = FALSE)
  )
}

shinyApp(ui, server)
