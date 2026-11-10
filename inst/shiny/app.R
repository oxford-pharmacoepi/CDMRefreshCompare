
library(shiny)
library(ggplot2)
library(DT)
library(plotly)
# ============================================================
# OMOP VOCABULARY TABLES
# ============================================================

vocabularyTables <- c(
  "CONCEPT",
  "VOCABULARY",
  "DOMAIN",
  "CONCEPT_CLASS",
  "RELATIONSHIP",
  "CONCEPT_RELATIONSHIP",
  "CONCEPT_ANCESTOR",
  "CONCEPT_SYNONYM",
  "DRUG_STRENGTH"
)
# ============================================================
# 1. GET CDM NAMES AND RESULTS FILE
# ============================================================

oldCdmName <- getOption(
  "CDMRefreshCompare.oldCdmName",
  "Old CDM"
)

newCdmName <- getOption(
  "CDMRefreshCompare.newCdmName",
  "New CDM"
)

result_file <- getOption(
  "CDMRefreshCompare.resultsFile",
  default = NULL
)

if (is.null(result_file)) {
  stop(
    "No results file provided. ",
    "Launch using launchComparisonExplorer()."
  )
}

result_file <- normalizePath(
  result_file,
  mustWork = TRUE
)

# ============================================================
# 2. READ COMPARISON RESULTS
# ============================================================

read_results <- function(path) {

  validate(
    need(
      file.exists(path),
      paste("Results file not found:", path)
    )
  )

  x <- tryCatch(
    read.csv(path, stringsAsFactors = FALSE),
    error = function(e) NULL
  )

  validate(
    need(!is.null(x), "Unable to read the results CSV.")
  )

  required <- c(
    "table",
    "old_count",
    "new_count",
    "difference",
    "percent_change"
  )

  validate(
    need(
      all(required %in% names(x)),
      paste(
        "CSV must contain:",
        paste(required, collapse = ", ")
      )
    )
  )

  for (nm in required[-1]) {
    x[[nm]] <- suppressWarnings(
      as.numeric(x[[nm]])
    )
  }

  validate(
    need(
      !anyNA(x[, c(
        "old_count",
        "new_count",
        "difference"
      )]),
      "Invalid numeric counts in CSV."
    )
  )

  x
}

# ============================================================
# 3. SHINY USER INTERFACE
# ============================================================

ui <- fluidPage(

  titlePanel("CDMRefreshCompare dashboard"),

  sidebarLayout(

    sidebarPanel(

      textInput(
        "file",
        "Comparison CSV path",
        value = result_file
      ),

      actionButton(
        "reload",
        "Load results"
      ),

      hr(),

      selectInput(
        inputId = "tableCategory",
        label = "Table category",
        choices = c(
          "All tables" = "all",
          "CDM tables" = "cdm",
          "Vocabulary tables" = "vocabulary"
        ),
        selected = "all"
      ),
      # Select individual tables within the chosen category
      selectInput(
        inputId = "tables",
        label = "Tables to display",
        choices = NULL,
        multiple = TRUE
      ),
      downloadButton(
        "download",
        "Download filtered CSV"
      ),

      helpText(
        "The dashboard reads saved aggregate results. ",
        "No database connection is needed."
      )
    ),

    mainPanel(

      # ------------------------------------------------------
      # SUMMARY CARDS
      # ------------------------------------------------------

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

      # ------------------------------------------------------
      # INTERACTIVE CHART
      # ------------------------------------------------------

      h3(textOutput("chartTitle")),

      p(
        "Hover over a bar to see the record counts. ",
        "Click a bar to view a detailed comparison."
      ),

      plotlyOutput(
        "changes",
        height = "600px"
      ),

      # ------------------------------------------------------
      # RESULTS TABLE
      # ------------------------------------------------------

      h3("Comparison details"),

      DTOutput("comparison"),

      p(
        "A change in record counts does not necessarily ",
        "indicate an ETL error."
      )
    )
  )
)

# ============================================================
# 4. SHINY SERVER
# ============================================================

server <- function(input, output, session) {

  output$chartTitle <- renderText({

    switch(
      input$tableCategory,
      "cdm" = "Change by CDM table",
      "vocabulary" = "Change by vocabulary table",
      "all" = "Change by all OMOP tables"
    )

  })

  # ----------------------------------------------------------
  # LOAD RESULTS
  # ----------------------------------------------------------

  results <- eventReactive(
    input$reload,
    read_results(input$file),
    ignoreNULL = FALSE
  )

  observeEvent(
    list(results(), input$tableCategory),
    {
      x <- results()

      isVocabulary <- toupper(x$table) %in%
        vocabularyTables

      if (input$tableCategory == "vocabulary") {
        x <- x[isVocabulary, , drop = FALSE]
      } else if (input$tableCategory == "cdm") {
        x <- x[!isVocabulary, , drop = FALSE]
      }

      updateSelectInput(
        session,
        "tables",
        choices = x$table,
        selected = x$table
      )
    }
  )

  # ----------------------------------------------------------
  # FILTER RESULTS
  # ----------------------------------------------------------

  filtered <- reactive({

    x <- results()

    # Apply category filter first
    isVocabulary <- toupper(x$table) %in%
      vocabularyTables

    if (input$tableCategory == "vocabulary") {

      x <- x[isVocabulary, , drop = FALSE]

    } else if (input$tableCategory == "cdm") {

      x <- x[!isVocabulary, , drop = FALSE]

    }

    # Apply selected table filter
    selectedTables <- input$tables

    if (is.null(selectedTables)) {
      selectedTables <- character(0)
    }

    x <- x[
      x$table %in% selectedTables,
      ,
      drop = FALSE
    ]

    x
  })

  # ----------------------------------------------------------
  # SUMMARY CARDS
  # ----------------------------------------------------------

  output$old_total <- renderText({

    format(
      sum(filtered()$old_count),
      big.mark = ",",
      scientific = FALSE
    )
  })

  output$new_total <- renderText({

    format(
      sum(filtered()$new_count),
      big.mark = ",",
      scientific = FALSE
    )
  })

  output$delta <- renderText({

    x <- filtered()

    old <- sum(x$old_count)

    if (old == 0) {
      return("N/A")
    }

    sprintf(
      "%+.2f%%",
      100 * (sum(x$new_count) - old) / old
    )
  })

  # ----------------------------------------------------------
  # INTERACTIVE PLOTLY CHART
  # ----------------------------------------------------------

  output$changes <- renderPlotly({

    x <- filtered()

    validate(
      need(
        nrow(x) > 0,
        "Select at least one table."
      )
    )

    # Create formatted hover information
    x$hover_text <- paste0(
      "<b>", x$table, "</b>",
      "<br>", oldCdmName, ": ",
      format(
        x$old_count,
        big.mark = ",",
        scientific = FALSE
      ),
      "<br>", newCdmName, ": ",
      format(
        x$new_count,
        big.mark = ",",
        scientific = FALSE
      ),
      "<br>Difference: ",
      format(
        x$difference,
        big.mark = ",",
        scientific = FALSE
      ),
      "<br>Change: ",
      ifelse(
        is.na(x$percent_change),
        "N/A",
        paste0(
          round(x$percent_change, 2),
          "%"
        )
      )
    )

    # Plotly interactive bar chart
    p <- plot_ly(
      data = x,
      x = ~percent_change,
      y = ~table,
      type = "bar",
      orientation = "h",
      key = ~table,
      text = ~hover_text,
      hoverinfo = "text",
      source = "cdm_table_chart",
      marker = list(
        color = "#2376A5"
      )
    )

    p <- layout(
      p,
      xaxis = list(
        title = "Change (%)",
        zeroline = TRUE
      ),
      yaxis = list(
        title = "CDM table",
        automargin = TRUE,
        categoryorder = "total ascending"
      ),
      margin = list(
        l = 180,
        r = 30,
        b = 60,
        t = 30
      )
    )

    event_register(
      p,
      "plotly_click"
    )
  })

  # ----------------------------------------------------------
  # CLICK-TO-DRILL-DOWN
  # ----------------------------------------------------------

  observeEvent(
    event_data(
      "plotly_click",
      source = "cdm_table_chart",
      priority = "event"
    ),
    {

      click <- event_data(
        "plotly_click",
        source = "cdm_table_chart"
      )

      req(click)
      req("key" %in% names(click))

      selectedTable <- as.character(
        click$key[[1]]
      )

      x <- filtered()

      selectedData <- x[
        x$table == selectedTable,
        ,
        drop = FALSE
      ]

      req(nrow(selectedData) == 1)

      comparisonData <- data.frame(
        CDM = c(
          oldCdmName,
          newCdmName
        ),
        Records = c(
          selectedData$old_count,
          selectedData$new_count
        )
      )

      # Show detailed popup
      showModal(
        modalDialog(

          title = paste(
            "CDM table:",
            selectedTable
          ),

          fluidRow(

            column(
              6,
              wellPanel(
                h4(oldCdmName),
                h3(
                  format(
                    selectedData$old_count,
                    big.mark = ","
                  )
                )
              )
            ),

            column(
              6,
              wellPanel(
                h4(newCdmName),
                h3(
                  format(
                    selectedData$new_count,
                    big.mark = ","
                  )
                )
              )
            )
          ),

          h4("Record count comparison"),

          plotlyOutput(
            "tableDrilldown",
            height = "350px"
          ),

          hr(),

          h4("Difference"),

          p(
            paste(
              "Absolute difference:",
              format(
                selectedData$difference,
                big.mark = ","
              )
            )
          ),

          p(
            paste(
              "Percentage change:",
              if (
                is.na(selectedData$percent_change)
              ) {
                "N/A"
              } else {
                paste0(
                  round(
                    selectedData$percent_change,
                    2
                  ),
                  "%"
                )
              }
            )
          ),

          p(
            "Record-count changes do not necessarily ",
            "indicate ETL errors."
          ),

          easyClose = TRUE,

          footer = modalButton("Close"),

          size = "l"
        )
      )

      # Render detailed chart
      output$tableDrilldown <- renderPlotly({

        plot_ly(
          data = comparisonData,
          x = ~CDM,
          y = ~Records,
          type = "bar",
          color = ~CDM,
          colors = c(
            "#2376A5",
            "#42A58C"
          ),
          text = ~format(
            Records,
            big.mark = ",",
            scientific = FALSE
          ),
          textposition = "auto",
          hovertemplate = paste0(
            "<b>%{x}</b>",
            "<br>Records: %{y:,}",
            "<extra></extra>"
          )
        ) |>
          layout(
            showlegend = FALSE,
            yaxis = list(
              title = "Number of records",
              rangemode = "tozero",
              tickformat = ","
            ),
            xaxis = list(
              title = ""
            )
          )
      })
    }
  )

  # ----------------------------------------------------------
  # INTERACTIVE RESULTS TABLE
  # ----------------------------------------------------------

  output$comparison <- renderDT({

    datatable(
      filtered(),
      rownames = FALSE,
      options = list(
        pageLength = 10,
        scrollX = TRUE
      ),
      filter = "top"
    )
  })

  # ----------------------------------------------------------
  # DOWNLOAD RESULTS
  # ----------------------------------------------------------

  output$download <- downloadHandler(

    filename = function() {
      paste0(
        "cdm_comparison_",
        Sys.Date(),
        ".csv"
      )
    },

    content = function(file) {
      write.csv(
        filtered(),
        file,
        row.names = FALSE
      )
    }
  )
}

shinyApp(ui, server)
