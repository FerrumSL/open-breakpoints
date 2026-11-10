# Coverage audit of WHONET's Breakpoints.txt.
# Usage: Rscript R/coverage.R [file] [reference_year]
# Reads the pinned copy (make whonet) and writes to out/:
#   coverage_by_year.csv      one row per guideline and year
#   coverage_by_table.csv     one row per guideline, year and REFERENCE_TABLE
#   coverage_by_organism.csv  one row per guideline, year and ORGANISM_CODE
#   coverage_summary.md       short tables for reading
# Human breakpoints of CLSI and EUCAST only. Counts say what is in the file;
# they do not say whether a value is correct.

source("R/common.R")

WHONET_SHA256 <- "c9c6e72844d144941051e0fa1919ae9698846993d21cce043693d0a25092d202"
WHONET_COMMIT <- "69de201"

read_whonet <- function(path) {
  d <- read_tsv(path)
  d <- d[d$BREAKPOINT_TYPE == "Human" & d$GUIDELINES %in% c("CLSI", "EUCAST"), ]
  d$YEAR <- as.integer(d$YEAR)
  d
}

n_distinct <- function(x) length(unique(x))

# One row per group, with counts. `by` is a character vector of column names.
count_groups <- function(d, by) {
  groups <- split(d, d[by], drop = TRUE, sep = "\r")
  rows <- lapply(groups, function(g) {
    data.frame(g[1, by, drop = FALSE],
               rows = nrow(g),
               mic_rows = sum(g$TEST_METHOD == "MIC"),
               disk_rows = sum(g$TEST_METHOD == "DISK"),
               drugs = n_distinct(g$WHONET_ABX_CODE),
               organism_codes = n_distinct(g$ORGANISM_CODE),
               check.names = FALSE)
  })
  out <- do.call(rbind, rows)
  out <- out[do.call(order, unname(out[by])), ]
  rownames(out) <- NULL
  out
}

coverage_by_year <- function(d) {
  out <- count_groups(d, c("GUIDELINES", "YEAR"))
  extra <- lapply(seq_len(nrow(out)), function(i) {
    g <- d[d$GUIDELINES == out$GUIDELINES[i] & d$YEAR == out$YEAR[i], ]
    ebc <- g[g$ORGANISM_CODE == "EBC", ]
    data.frame(rows_without_table = sum(g$REFERENCE_TABLE == ""),
               tables = n_distinct(g$REFERENCE_TABLE[g$REFERENCE_TABLE != ""]),
               ebc_family_rows = nrow(ebc),
               ebc_family_drugs = n_distinct(ebc$WHONET_ABX_CODE))
  })
  cbind(out, do.call(rbind, extra))
}

# Adds, for each organism code, how many of its reference-year drugs the year has.
coverage_by_organism <- function(d, ref_year) {
  out <- count_groups(d, c("GUIDELINES", "YEAR", "ORGANISM_CODE", "ORGANISM_CODE_TYPE"))
  out$organism_codes <- NULL
  drugs <- lapply(split(d$WHONET_ABX_CODE, list(d$GUIDELINES, d$YEAR, d$ORGANISM_CODE),
                        drop = TRUE, sep = "\r"), unique)
  key <- function(gl, yr, org) paste(gl, yr, org, sep = "\r")
  out$drugs_ref_year <- 0L
  out$ref_year_drugs_present <- 0L
  for (i in seq_len(nrow(out))) {
    ref <- drugs[[key(out$GUIDELINES[i], ref_year, out$ORGANISM_CODE[i])]]
    own <- drugs[[key(out$GUIDELINES[i], out$YEAR[i], out$ORGANISM_CODE[i])]]
    out$drugs_ref_year[i] <- length(ref)
    out$ref_year_drugs_present[i] <- sum(ref %in% own)
  }
  out
}

# Organism codes that have rows in the reference year and none in an earlier year.
absent_codes <- function(d, ref_year) {
  out <- list()
  for (gl in unique(d$GUIDELINES)) {
    ref <- d[d$GUIDELINES == gl & d$YEAR == ref_year, ]
    ref_n <- table(ref$ORGANISM_CODE)
    for (yr in sort(unique(d$YEAR[d$GUIDELINES == gl & d$YEAR < ref_year]))) {
      have <- unique(d$ORGANISM_CODE[d$GUIDELINES == gl & d$YEAR == yr])
      miss <- sort(ref_n[!(names(ref_n) %in% have)], decreasing = TRUE)
      out[[length(out) + 1]] <- data.frame(
        GUIDELINES = gl, YEAR = yr, codes_absent = length(miss), ref_rows_absent = sum(miss),
        largest = paste(sprintf("%s (%d)", names(miss), miss)[seq_len(min(5, length(miss)))],
                        collapse = ", "))
    }
  }
  do.call(rbind, out)
}

md_table <- function(x) {
  c(paste("|", paste(names(x), collapse = " | "), "|"),
    paste("|", paste(rep("---", ncol(x)), collapse = " | "), "|"),
    apply(x, 1, function(r) paste("|", paste(trimws(r), collapse = " | "), "|")))
}

write_summary <- function(by_year, absent, ref_year, path, file_sha) {
  lines <- c(
    "# Coverage of WHONET Breakpoints.txt",
    "",
    sprintf("File: AMRIE commit %s, SHA-256 %s.", WHONET_COMMIT, file_sha),
    "Human breakpoints of CLSI and EUCAST. Counts of rows present in the file; values were not checked.",
    "`EBC family rows`: rows with ORGANISM_CODE EBC (Enterobacterales).",
    "`Rows without table`: rows with an empty REFERENCE_TABLE.",
    "An absent organism code is not always a gap: the guideline may not have covered that organism in that year.",
    "")
  for (gl in unique(by_year$GUIDELINES)) {
    y <- by_year[by_year$GUIDELINES == gl,
                 c("YEAR", "rows", "rows_without_table", "tables", "organism_codes", "drugs",
                   "ebc_family_rows", "ebc_family_drugs")]
    names(y) <- c("Year", "Rows", "Rows without table", "Tables", "Organism codes", "Drugs",
                  "EBC family rows", "EBC family drugs")
    a <- absent[absent$GUIDELINES == gl, c("YEAR", "codes_absent", "ref_rows_absent", "largest")]
    names(a) <- c("Year", "Codes absent", sprintf("Their rows in %d", ref_year),
                  sprintf("Largest (rows in %d)", ref_year))
    lines <- c(lines, sprintf("## %s", gl), "", md_table(y), "",
               sprintf("Organism codes with rows in %s %d and none in the year:", gl, ref_year), "",
               md_table(a), "")
  }
  writeLines(lines, path)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  file <- if (length(args) > 0) args[1] else "sources/whonet/Breakpoints.txt"
  ref_year <- if (length(args) > 1) as.integer(args[2]) else 2020L
  sha <- unname(tools::sha256sum(file))
  if (sha != WHONET_SHA256) warning("file differs from the pinned copy; counts may differ")
  d <- read_whonet(file)
  dir.create("out", showWarnings = FALSE)
  by_year <- coverage_by_year(d)
  absent <- absent_codes(d, ref_year)
  write.csv(by_year, "out/coverage_by_year.csv", row.names = FALSE)
  write.csv(count_groups(d, c("GUIDELINES", "YEAR", "REFERENCE_TABLE")),
            "out/coverage_by_table.csv", row.names = FALSE)
  write.csv(coverage_by_organism(d, ref_year), "out/coverage_by_organism.csv", row.names = FALSE)
  write_summary(by_year, absent, ref_year, "out/coverage_summary.md", sha)
  cat("wrote out/coverage_*.csv and out/coverage_summary.md\n")
}
