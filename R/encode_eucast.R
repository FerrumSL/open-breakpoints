# Turn extracted EUCAST cells into rows in WHONET's conventions (schema v0, STATUS "draft").
# Usage: Rscript R/encode_eucast.R <xls_cells.tsv> <year> <source_id> <out_dir> <date_entered>
# Writes <out_dir>/rows.tsv and <out_dir>/flags.tsv.
# <date_entered> (YYYY-MM-DD) is fixed per table in the Makefile, so that generating the rows
# again on another day gives the same file.
#
# Conventions, read from WHONET's own EUCAST rows (2012 and 2013) and tested against them:
#   MIC   EUCAST prints "S <= a, R > b".  WHONET stores S = a and R = 2 * b.
#   Disk  EUCAST prints "S >= a, R < b".  WHONET stores S = a, R = b - 1,
#         I = "-" when nothing lies between, otherwise "<b>-<a - 1>".
#   Cells with "-", "NA", "IE" or "Note" give no row.
#   REFERENCE_TABLE is the sheet name. POTENCY and WHONET_TEST are looked up in WHONET's file.
# Anything that needed a decision is written to flags.tsv for a reviewer.

source("R/common.R")

is_num <- function(x) grepl("^[0-9]+(\\.[0-9]+)?$", x)

mic_r <- function(r_above) format(2 * as.numeric(r_above), drop0trailing = TRUE, scientific = FALSE)

disk_r <- function(r_below) as.character(as.numeric(r_below) - 1)

disk_i <- function(s_from, r_below) {
  s <- as.numeric(s_from); b <- as.numeric(r_below)
  ifelse(s <= b, "-", paste0(b, "-", s - 1))
}

# "Cefixime (uncomplicated UTI only)" -> drug "Cefixime", qualifier "uncomplicated UTI only"
split_label <- function(label) {
  q <- ifelse(grepl("\\(", label), sub("^[^(]*\\(([^)]*)\\).*$", "\\1", label), "")
  list(drug = trimws(sub("\\s*\\(.*$", "", label)), qualifier = q)
}

site_of <- function(qualifier) {
  ifelse(qualifier %in% c("uncomplicated UTI only", "UTI only"),
         "Uncomplicated urinary tract infection", "")
}

# POTENCY and WHONET_TEST as WHONET writes them for this drug and disk content.
disk_codes <- function(whonet, code, content) {
  w <- whonet[whonet$GUIDELINES == "EUCAST" & whonet$TEST_METHOD == "DISK" &
                whonet$WHONET_ABX_CODE == code, c("POTENCY", "WHONET_TEST")]
  ours <- paste0(gsub("-", "/", content), "µg")
  exact <- w[w$POTENCY == ours, ]
  same_first <- w[sub("[/µ].*$", "", w$POTENCY) == sub("-.*$", "", content), ]
  pick <- if (nrow(exact) > 0) exact else same_first
  if (nrow(pick) == 0) return(list(potency = ours, test = "", how = "not in WHONET's file"))
  top <- names(sort(table(paste(pick$POTENCY, pick$WHONET_TEST, sep = "\t")), decreasing = TRUE))[1]
  top <- strsplit(top, "\t")[[1]]
  list(potency = top[1], test = top[2],
       how = if (nrow(exact) > 0) "" else sprintf("source prints %s; WHONET's label used", content))
}

encode <- function(cells, year, source_id, tables, drugs, whonet, date_entered) {
  rows <- list(); flags <- list()
  flag <- function(c, what, proposed) {
    flags[[length(flags) + 1]] <<- data.frame(
      sheet = c$sheet, row = c$row, label = c$label, what = what, proposed = proposed,
      reviewer = "", decision = "", date = "")
  }
  cells <- cells[cells$sheet %in% tables$sheet, ]
  for (i in seq_len(nrow(cells))) {
    c <- cells[i, ]
    has_mic <- is_num(c$mic_s) && is_num(c$mic_r)
    has_disk <- is_num(c$zone_s) && is_num(c$zone_r)
    lab <- split_label(c$label)
    if ((has_mic || has_disk) && lengths(regmatches(c$label, gregexpr("(", c$label, fixed = TRUE))) > 1) {
      stop(sprintf("more than one qualifier in '%s' (sheet %s, row %s): no rule for that", c$label, c$sheet, c$row))
    }
    if (!has_mic && !has_disk) {
      special <- setdiff(unlist(c[c("mic_s", "mic_r", "zone_s", "zone_r")]), c("-", ""))
      if (length(special) > 0) {
        flag(c, sprintf("no numeric breakpoint: %s", toString(unique(special))), "no row")
      }
      next
    }
    d <- drugs[drugs$drug == lab$drug, ]
    if (nrow(d) == 0 && grepl("[0-9]$", lab$drug)) {
      # A footnote mark that the workbook does not format as superscript, e.g. "Ciprofloxacin1".
      plain <- sub("[0-9]+$", "", lab$drug)
      d <- drugs[drugs$drug == plain, ]
      if (nrow(d) == 1) {
        flag(c, sprintf("drug name printed as '%s': the trailing digit is read as a footnote mark",
                        lab$drug), sprintf("drug %s", plain))
      }
    }
    if (nrow(d) != 1) stop(sprintf("no drug code for '%s' (sheet %s, row %s)", lab$drug, c$sheet, c$row))
    t <- tables[tables$sheet == c$sheet, ]
    orgs <- if (d$organisms == "") t$ORGANISM_CODE else strsplit(d$organisms, ",")[[1]]
    org_type <- if (d$organisms == "") t$ORGANISM_CODE_TYPE else "WHONET_ORG_CODE"
    site <- site_of(lab$qualifier)

    if (d$organisms != "") flag(c, d$note, sprintf("rows for %s", d$organisms))
    # A footnote limits the breakpoint to some species, but WHONET's later rows keep the family.
    if (d$organisms == "" && d$note != "") flag(c, d$note, "family row kept; reviewer decides")
    if (lab$qualifier != "") {
      flag(c, sprintf("qualifier in the drug name: (%s)", lab$qualifier),
           if (site != "") sprintf("SITE_OF_INFECTION = %s", site) else "no SITE_OF_INFECTION")
    }
    if (grepl(" iv$|-trometamol$", lab$drug)) {
      flag(c, "route or salt in the drug name", sprintf("code %s", d$WHONET_ABX_CODE))
    }
    marks <- unlist(c[c("label_sup", "mic_s_sup", "mic_r_sup", "disk_sup", "zone_s_sup", "zone_r_sup")])
    marks <- unique(marks[marks != ""])
    if (length(marks) > 0) {
      flag(c, sprintf("footnote marks: %s", paste(marks, collapse = " ")), "values as printed; read the footnotes")
    }
    if (has_mic != has_disk) {
      other <- if (has_mic) c(c$zone_s, c$zone_r) else c(c$mic_s, c$mic_r)
      flag(c, sprintf("only %s has numbers; the other side prints: %s",
                      if (has_mic) "MIC" else "disk", toString(unique(other))),
           sprintf("%s row only", if (has_mic) "MIC" else "disk"))
    }

    base <- data.frame(
      GUIDELINES = "EUCAST", YEAR = as.character(year), TEST_METHOD = "", POTENCY = "",
      ORGANISM_CODE = orgs, ORGANISM_CODE_TYPE = org_type, BREAKPOINT_TYPE = "Human",
      HOST = "Human", SITE_OF_INFECTION = site, REFERENCE_TABLE = c$sheet,
      REFERENCE_SEQUENCE = "", WHONET_ABX_CODE = d$WHONET_ABX_CODE, WHONET_TEST = "",
      R = "", I = "", SDD = "", S = "", ECV_ECOFF = "", ECV_ECOFF_TENTATIVE = "",
      DATE_ENTERED = date_entered, DATE_MODIFIED = "", COMMENTS = "",
      SOURCE_ID = source_id, SOURCE_LOCATOR = sprintf("sheet %s, row %s", c$sheet, c$row),
      STATUS = "draft")
    if (has_mic) {
      if (as.numeric(c$mic_s) < 0.25 || as.numeric(c$mic_r) < 0.25) {
        stop("MIC below 0.25: WHONET's spelling of low dilutions (0.032, 0.125, 0.12) is not settled")
      }
      m <- base
      m$TEST_METHOD <- "MIC"; m$WHONET_TEST <- paste0(d$WHONET_ABX_CODE, "_EM")
      m$S <- c$mic_s; m$R <- mic_r(c$mic_r)
      rows[[length(rows) + 1]] <- m
    }
    if (has_disk) {
      k <- disk_codes(whonet, d$WHONET_ABX_CODE, c$disk)
      if (k$how != "") flag(c, sprintf("disk content: %s", k$how), sprintf("POTENCY = %s", k$potency))
      z <- base
      z$TEST_METHOD <- "DISK"; z$POTENCY <- k$potency; z$WHONET_TEST <- k$test
      z$S <- c$zone_s; z$R <- disk_r(c$zone_r); z$I <- disk_i(c$zone_s, c$zone_r)
      rows[[length(rows) + 1]] <- z
    }
  }
  list(rows = do.call(rbind, rows), flags = do.call(rbind, flags))
}

write_tsv <- function(d, path) {
  write.table(d, path, sep = "\t", quote = FALSE, row.names = FALSE, na = "", fileEncoding = "UTF-8")
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  stopifnot(length(args) == 5, grepl("^\\d{4}-\\d{2}-\\d{2}$", args[5]))
  r <- encode(read_tsv(args[1]), args[2], args[3], read_tsv("maps/eucast_tables.tsv"),
              read_tsv("maps/eucast_drugs.tsv"), read_tsv("sources/whonet/Breakpoints.txt"), args[5])
  write_tsv(r$rows, file.path(args[4], "rows.tsv"))
  write_tsv(r$flags, file.path(args[4], "flags.tsv"))
  cat(sprintf("%d rows, %d flags\n", nrow(r$rows), nrow(r$flags)))
  print(table(r$rows$ORGANISM_CODE, r$rows$TEST_METHOD))
}
