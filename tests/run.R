# Run from the repository root: Rscript tests/run.R
# The fixture is synthetic (guideline "TEST"); it holds no real breakpoint values.

source("R/validate.R")
source("R/export_whonet.R")

fixture <- "tests/fixture"
file <- file.path(fixture, "breakpoints/TEST/2000.tsv")

# 1. The fixture is valid.
stopifnot(length(validate_dir(fixture)) == 0)

# 2. Export keeps WHONET's 22 columns, in order, with every value unchanged.
out <- tempfile(fileext = ".txt")
export_whonet(file, out)
d <- read_tsv(file)
e <- read_tsv(out)
stopifnot(ncol(e) == 22, identical(e, d[1:22]))
raw <- readBin(out, "raw", file.size(out))
stopifnot(sum(raw == as.raw(13)) == nrow(d) + 1)  # CRLF on every line

# 3. The rules catch what they should.
schema <- read_schema()
sources <- read_tsv(file.path(fixture, "sources.tsv"))
bad <- d; bad$S[1] <- "8"                       # MIC with S above R
stopifnot(any(grepl("wrong order", check_rules(bad, sources))))
bad <- d; bad$S[1] <- "81"                      # 8 with footnote mark 1 read as one value
stopifnot(any(grepl("doubling scale", check_rules(bad, sources))))
ok <- d; ok$S[1] <- "0.032"; ok$R[1] <- "0.125"; ok$S[2] <- "21"  # WHONET spellings; disk rows are not on the scale
stopifnot(!any(grepl("doubling scale", check_rules(ok, sources))))
bad <- d; bad$SOURCE_ID[2] <- "nowhere"
stopifnot(any(grepl("SOURCE_ID", check_rules(bad, sources))))
bad <- rbind(d, d[1, ])
stopifnot(any(grepl("duplicate", check_rules(bad, sources))))
bad <- d; bad$STATUS[1] <- "fine"
stopifnot(any(grepl("STATUS", check_schema(bad, schema))))
bad <- d; bad$YEAR[1] <- "20x0"
stopifnot(any(grepl("YEAR", check_schema(bad, schema))))

# 3b. EUCAST to WHONET conversion rules.
source("R/encode_eucast.R")
stopifnot(mic_r("8") == "16", mic_r("0.5") == "1", mic_r("0.25") == "0.5")
stopifnot(disk_r("14") == "13", disk_i("14", "14") == "-", disk_i("22", "19") == "19-21")
stopifnot(split_label("Cefixime (uncomplicated UTI only)")$drug == "Cefixime",
          site_of("uncomplicated UTI only") == "Uncomplicated urinary tract infection",
          site_of("screen") == "", split_label("Cefepime")$qualifier == "")

# 3c. Comparison of the two extractions: a changed cell and a missing row are both reported.
source("R/compare_extractions.R")
cell <- function(...) data.frame(..., stringsAsFactors = FALSE)
xls <- cell(sheet = "T", row = c("5", "6"), label = c("Drug A", "Drug B"), label_sup = c("1", ""),
            mic_s = c("8", "1"), mic_s_sup = c("2", ""), mic_r = c("8", "2"), mic_r_sup = "",
            disk = "10", disk_sup = "", zone_s = "20", zone_s_sup = "", zone_r = "17", zone_r_sup = "")
pdf <- cell(table_no = "1", title = "T", page = "3", label = c("Drug A1", "Drug B"),
            mic_s = c("82", "1"), mic_r = c("8", "2"), disk = "10", zone_s = "20", zone_r = "17")
stopifnot(is.null(compare(xls, pdf)$diffs), compare(xls, pdf)$cells == 10)
changed <- pdf; changed$mic_r[2] <- "4"
stopifnot(nrow(compare(xls, changed)$diffs) == 1, compare(xls, changed)$diffs$field == "mic_r")
stopifnot(sum(compare(xls, pdf[1, ])$diffs$field == "(row)") == 1)

# 3d. Link audit helpers: one row per code, first filled value; members of a group code.
source("R/link_coverage.R")
lst <- cell(CODE = c("a", "a", "b"), X = c("", "x1", ""), Y = c("y1", "y2", ""))
one <- collapse(lst, "CODE")
stopifnot(nrow(one) == 2, one$X[one$CODE == "a"] == "x1", one$Y[one$CODE == "a"] == "y1",
          one$X[one$CODE == "b"] == "", identical(disagree(lst, "CODE", "Y"), "a"))
org <- cell(WHONET_ORG_CODE = c("eco", "kpn", "pae"), FAMILY_CODE = c("EBC", "EBC", ""),
            ANAEROBE = "", SUBKINGDOM_CODE = "-")
stopifnot(members(org, "EBC", "FAMILY_CODE") == 2, is.na(members(org, "ALL", "ALL")))

# 4. Coverage counts on the pinned WHONET file, if it has been downloaded (make whonet).
# Expected values were counted independently in October 2026.
whonet <- "sources/whonet/Breakpoints.txt"
if (file.exists(whonet)) {
  source("R/coverage.R")
  stopifnot(unname(tools::sha256sum(whonet)) == WHONET_SHA256)
  w <- read_whonet(whonet)
  clsi <- function(year) w[w$GUIDELINES == "CLSI" & w$YEAR == year, ]
  in_2a <- function(x) startsWith(x$REFERENCE_TABLE, "Table 2A")
  fam <- function(year) { x <- clsi(year); sum(in_2a(x) & x$ORGANISM_CODE == "EBC") }
  all2a <- function(year) sum(in_2a(clsi(year)))
  stopifnot(fam(2011) == 0, fam(2015) == 2, fam(2019) == 4, fam(2020) == 135)
  stopifnot(all2a(2015) == 13, all2a(2019) == 19, all2a(2020) == 150)
  stopifnot(nrow(clsi(2015)) == 13 + 1099, nrow(clsi(2020)) == 150 + 1152)
  by_year <- coverage_by_year(w)
  stopifnot(sum(by_year$rows) == nrow(w))
  # Reading WHONET's file and writing it back as the export does gives the same bytes.
  back <- tempfile()
  write.table(read_tsv(whonet), back, sep = "\t", quote = FALSE, row.names = FALSE, na = "",
              eol = "\r\n", fileEncoding = "UTF-8")
  stopifnot(unname(tools::sha256sum(back)) == WHONET_SHA256)
} else {
  cat("skipped: WHONET file not downloaded\n")
}

cat("all tests passed\n")
