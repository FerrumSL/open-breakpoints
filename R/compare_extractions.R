# Compare the Excel extraction (extract/eucast.py) with the PDF extraction
# (R/extract_eucast_pdf.R), cell by cell.
# Usage: Rscript R/compare_extractions.R <xls_cells.tsv> <pdf_cells.tsv> <differences.tsv>
# Rows are matched by table (in document order), label and occurrence. A cell agrees when the
# Excel text plus its footnote marks equals the PDF token, ignoring spaces.
# Exit status 1 if anything differs. Every difference is resolved by a person.

source("R/common.R")

squash <- function(x) gsub("\\s", "", x)
FIELDS <- c("mic_s", "mic_r", "disk", "zone_s", "zone_r")

add_key <- function(d, table_no, label) {
  d$key_label <- tolower(squash(label))
  d$table_no <- table_no
  d$occurrence <- ave(seq_len(nrow(d)), d$table_no, d$key_label, FUN = seq_along)
  d$key <- paste(d$table_no, d$key_label, d$occurrence, sep = "|")
  d
}

compare <- function(xls, pdf) {
  xls <- add_key(xls, match(xls$sheet, unique(xls$sheet)), paste0(xls$label, xls$label_sup))
  pdf <- add_key(pdf, as.integer(pdf$table_no), pdf$label)
  diffs <- list()
  add <- function(...) diffs[[length(diffs) + 1]] <<- data.frame(..., check.names = FALSE)
  for (i in which(!(xls$key %in% pdf$key))) {
    add(sheet = xls$sheet[i], xls_row = xls$row[i], pdf_page = "", label = xls$label[i],
        field = "(row)", xls = "present", pdf = "not found")
  }
  # A row found only in the PDF is reported under the Excel sheet name of its table, so that
  # every difference of a table carries the same name. The PDF title is the fallback.
  sheets <- unique(xls$sheet)
  for (i in which(!(pdf$key %in% xls$key))) {
    s <- sheets[pdf$table_no[i]]
    add(sheet = if (is.na(s)) pdf$title[i] else s, xls_row = "", pdf_page = pdf$page[i], label = pdf$label[i],
        field = "(row)", xls = "not found", pdf = "present")
  }
  m <- merge(xls, pdf, by = "key", suffixes = c(".x", ".p"))
  cells <- 0
  for (f in FIELDS) {
    a <- squash(paste0(m[[paste0(f, ".x")]], m[[paste0(f, "_sup")]]))
    b <- squash(m[[paste0(f, ".p")]])
    cells <- cells + nrow(m)
    for (i in which(a != b)) {
      add(sheet = m$sheet[i], xls_row = m$row[i], pdf_page = m$page[i], label = m$label.x[i],
          field = f, xls = a[i], pdf = b[i])
    }
  }
  list(diffs = if (length(diffs)) do.call(rbind, diffs) else NULL,
       rows_xls = nrow(xls), rows_pdf = nrow(pdf), rows_matched = nrow(m), cells = cells,
       matched_sheets = m$sheet)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 3)
  r <- compare(read_tsv(args[1]), read_tsv(args[2]))
  n <- if (is.null(r$diffs)) 0 else nrow(r$diffs)
  if (n > 0) {
    write.table(r$diffs, args[3], sep = "\t", quote = FALSE, row.names = FALSE)
  } else if (file.exists(args[3])) {
    file.remove(args[3])
  }
  cat(sprintf("rows: %d Excel, %d PDF, %d matched; %d cells compared; %d differences\n",
              r$rows_xls, r$rows_pdf, r$rows_matched, r$cells, n))
  if (n > 0) quit(status = 1)
}
