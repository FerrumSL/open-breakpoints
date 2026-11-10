# Validate every breakpoint file under <dir>/breakpoints against the schema and the coded rules.
# Usage: Rscript R/validate.R [dir]   (dir defaults to "data")
# Exit status 1 if any problem is found.

source("R/common.R")

# Schema checks: columns, required, integer range, pattern, enum.
check_schema <- function(d, schema) {
  out <- character(0)
  names_expected <- vapply(schema$fields, function(f) f$name, "")
  if (!identical(names(d), names_expected)) {
    return("columns differ from schema (names or order)")
  }
  for (f in schema$fields) {
    x <- d[[f$name]]
    k <- f$constraints
    filled <- x != ""
    if (isTRUE(k$required) && any(!filled)) {
      out <- c(out, sprintf("%s: empty in row(s) %s", f$name, toString(which(!filled))))
    }
    if (f$type == "integer") {
      n <- suppressWarnings(as.integer(x))
      bad <- filled & (is.na(n) | as.character(n) != x)
      if (!is.null(k$minimum)) bad <- bad | (!is.na(n) & n < k$minimum)
      if (!is.null(k$maximum)) bad <- bad | (!is.na(n) & n > k$maximum)
      if (any(bad)) out <- c(out, sprintf("%s: not a valid integer in row(s) %s", f$name, toString(which(bad))))
    }
    if (!is.null(k$pattern)) {
      bad <- filled & !grepl(k$pattern, x, perl = TRUE)
      if (any(bad)) out <- c(out, sprintf("%s: wrong format in row(s) %s", f$name, toString(which(bad))))
    }
    if (!is.null(k$enum)) {
      bad <- filled & !(x %in% unlist(k$enum))
      if (any(bad)) out <- c(out, sprintf("%s: value not allowed in row(s) %s", f$name, toString(which(bad))))
    }
  }
  out
}

# MIC values that a breakpoint can take: the doubling scale, in the spellings WHONET's file uses.
# A fixed list, on purpose. WHONET's file also has 0.0001, 129, 513 and 1025; their rule is not
# known to us, so they are reported until WHONET explains them. Then extend the list.
MIC_SCALE <- c("0.001", "0.002", "0.004", "0.008", "0.015", "0.016", "0.03", "0.032", "0.06",
               "0.064", "0.12", "0.125", "0.25", "0.5", as.character(2^(0:10)))

# Coded rules: checks that need more than one column or more than one row.
check_rules <- function(d, sources) {
  out <- character(0)

  key <- c("GUIDELINES", "YEAR", "TEST_METHOD", "POTENCY", "ORGANISM_CODE", "BREAKPOINT_TYPE",
           "HOST", "SITE_OF_INFECTION", "WHONET_TEST")
  dup <- duplicated(d[key])
  if (any(dup)) out <- c(out, sprintf("duplicate breakpoint key in row(s) %s", toString(which(dup))))

  # MIC: susceptible at or below S, resistant at or above R, so S must not exceed R.
  # Disk: zone diameters run the other way.
  s <- suppressWarnings(as.numeric(d$S))
  r <- suppressWarnings(as.numeric(d$R))
  both <- !is.na(s) & !is.na(r)
  bad <- both & ((d$TEST_METHOD == "MIC" & s > r) | (d$TEST_METHOD == "DISK" & s < r))
  if (any(bad)) out <- c(out, sprintf("S and R in the wrong order in row(s) %s", toString(which(bad))))

  # A footnote mark read as part of a value ("81" for 8 with footnote 1) leaves the scale.
  # It cannot catch every such case: 1 with footnote 6 reads as 16.
  off <- function(x) d$TEST_METHOD == "MIC" & x != "" & !(x %in% MIC_SCALE)
  bad <- off(d$S) | off(d$R)
  if (any(bad)) out <- c(out, sprintf("MIC value off the doubling scale in row(s) %s", toString(which(bad))))

  bad <- !(d$SOURCE_ID %in% sources$SOURCE_ID)
  if (any(bad)) out <- c(out, sprintf("SOURCE_ID not in sources.tsv in row(s) %s", toString(which(bad))))

  # Planned rules, not written yet:
  #   family-level rows are present for every table that has them in the source document;
  #   every change against the previous year matches a revision listed by the guideline;
  #   organism and antibiotic codes exist in WHONET's code lists.
  out
}

validate_dir <- function(dir) {
  schema <- read_schema()
  sources <- read_tsv(file.path(dir, "sources.tsv"))
  problems <- list()
  for (f in breakpoint_files(dir)) {
    d <- read_tsv(f)
    p <- check_schema(d, schema)
    if (length(p) == 0) p <- check_rules(d, sources)
    if (length(p) > 0) problems[[f]] <- p
  }
  problems
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  dir <- if (length(args) > 0) args[1] else "data"
  problems <- validate_dir(dir)
  for (f in names(problems)) cat(f, paste0("  ", problems[[f]]), sep = "\n")
  cat(sprintf("%d file(s) checked, %d with problems\n", length(breakpoint_files(dir)), length(problems)))
  if (length(problems) > 0) quit(status = 1)
}
