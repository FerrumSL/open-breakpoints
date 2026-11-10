# Export one breakpoint file to WHONET's Breakpoints.txt format:
# the first 22 columns only, tab-separated, CRLF line ends, no quoting.
# Usage: Rscript R/export_whonet.R <in.tsv> <out.txt>

source("R/common.R")

export_whonet <- function(infile, outfile) {
  d <- read_tsv(infile)
  n <- read_schema()$whonetFields
  write.table(d[seq_len(n)], outfile, sep = "\t", quote = FALSE, row.names = FALSE,
              na = "", eol = "\r\n", fileEncoding = "UTF-8")
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 2)
  export_whonet(args[1], args[2])
}
