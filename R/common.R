# Shared helpers. Everything is read as text so that export reproduces the input exactly.

# Sort the same way on every machine, so that generated files do not depend on the locale.
invisible(Sys.setlocale("LC_COLLATE", "C"))

read_tsv <- function(path) {
  read.delim(path, colClasses = "character", na.strings = character(0), quote = "",
             check.names = FALSE, comment.char = "", fileEncoding = "UTF-8")
}

read_schema <- function(path = "schema/breakpoints.schema.json") {
  jsonlite::fromJSON(path, simplifyVector = FALSE)
}

breakpoint_files <- function(dir) {
  sort(list.files(file.path(dir, "breakpoints"), pattern = "\\.tsv$", recursive = TRUE,
                  full.names = TRUE))
}
