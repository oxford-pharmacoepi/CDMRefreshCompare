# Add the CDMRefreshCompare Shiny dashboard

1. Copy `inst/shiny/app.R` into your package's `inst/shiny/app.R`.
2. Copy `R/launchComparisonExplorer.R` into your package's `R/` folder.
3. Add `shiny`, `ggplot2`, and `DT` under `Imports:` in DESCRIPTION (keep existing imports).
4. Run `devtools::document()`, then `devtools::install()`.
5. After running `extras/CodeToRun.R`, launch with:

```r
CDMRefreshCompare::launchComparisonExplorer(
  resultsFile = here::here("comparison_results", "cdm_refresh_counts.csv")
)
```

This dashboard reads aggregate CSV data; it does not connect to either CDM.
