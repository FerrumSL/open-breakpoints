# Second, independent extraction: EUCAST breakpoint table PDF to one row per drug line.
# Usage: Rscript R/extract_eucast_pdf.R <tables.pdf> <out.tsv>
# Needs the pdftotext program (poppler). Reads the text layout only: a cell and its footnote
# marks arrive as one token ("81" is 8 with footnote 1), so tokens are written as printed and
# R/compare_extractions.R compares them with the Excel extraction, which separates the two.
# A line that holds values but cannot be read as a drug line (the drug name is on another line,
# or the line is indented) is not dropped silently: it goes to <out>_dropped.tsv, and
# R/report_eucast.R counts such lines for the tables in use.

# A value token: number, dash, NA, IE, IP, "Note", disk content, each with optional footnote marks.
is_value <- function(x) grepl("^(Note)?[0-9A-Z.,/ -]+$|^Note$|^1 unit$", x) & nchar(x) <= 14

page_text <- function(pdf, page) {
  system2("pdftotext", c("-layout", "-f", page, "-l", page, shQuote(pdf), "-"), stdout = TRUE)
}

n_pages <- function(pdf) {
  info <- system2("pdfinfo", shQuote(pdf), stdout = TRUE)
  as.integer(sub("^Pages:\\s+", "", grep("^Pages:", info, value = TRUE)))
}

# A token that looks like a table value, for finding value lines that could not be read.
looks_like_value <- function(tok) is_value(tok) & grepl("^([0-9]|Note|IE|NA|IP|-)", tok)

extract_pdf <- function(pdf) {
  out <- list(); dropped <- list()
  for (p in seq_len(n_pages(pdf))) {
    lines <- page_text(pdf, p)
    lines <- lines[trimws(lines) != ""]
    if (length(lines) == 0) next
    title <- strsplit(trimws(lines[1]), " {2,}")[[1]][1]
    if (grepl("^European Committee", title)) next          # front pages
    for (line in lines[-1]) {
      tok <- strsplit(trimws(line), " {2,}")[[1]]
      n <- 0
      while (n < length(tok) - 1 && n < 5 && is_value(tok[n + 2])) n <- n + 1
      # A drug line starts at the left edge (header and note lines start with spaces) and has
      # a name and at least two values.
      if (grepl("^\\s", line) || length(tok) < 3 || n < 2) {
        if (sum(looks_like_value(tok)) >= 2) {
          dropped[[length(dropped) + 1]] <- data.frame(title = title, page = p, line = trimws(line))
        }
        next
      }
      v <- tok[2:(n + 1)]
      # 5 values: MIC S, MIC R, disk content, zone S, zone R. 4: disk content is blank. 2: MIC only.
      cells <- switch(as.character(n),
                      "5" = v,
                      "4" = c(v[1:2], "", v[3:4]),
                      "2" = c(v, "", "", ""),
                      c(v, rep("?", 5 - n)))
      out[[length(out) + 1]] <- data.frame(
        title = title, page = p, label = tok[1],
        mic_s = cells[1], mic_r = cells[2], disk = cells[3], zone_s = cells[4], zone_r = cells[5])
    }
  }
  out <- do.call(rbind, out)
  # Tables are numbered in document order, counting only titles that have drug lines.
  out <- cbind(table_no = match(out$title, unique(out$title)), out)
  dropped <- if (length(dropped)) do.call(rbind, dropped) else
    data.frame(title = character(0), page = integer(0), line = character(0))
  list(rows = out, dropped = dropped)
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 2)
  r <- extract_pdf(args[1])
  write.table(r$rows, args[2], sep = "\t", quote = FALSE, row.names = FALSE, fileEncoding = "UTF-8")
  write.table(r$dropped, sub("\\.tsv$", "_dropped.tsv", args[2]), sep = "\t", quote = FALSE,
              row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("%d drug lines; %d value lines could not be read as a drug line\n",
              nrow(r$rows), nrow(r$dropped)))
}
