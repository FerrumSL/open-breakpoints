# Link audit: which codes used in WHONET's Breakpoints.txt already have an outside identifier
# in WHONET's own lists (Antibiotics.txt: ATC, LOINC; Organisms.txt: SNOMED CT, GBIF).
# Usage: Rscript R/link_coverage.R   (after `make whonet-lists`)
# Human breakpoints of CLSI and EUCAST, as in R/coverage.R. Writes to out/:
#   link_drugs.csv      one row per drug code in use
#   link_organisms.csv  one row per organism code in use
#   link_by_year.csv    rows per guideline and year, by what resolves
#   link_coverage.md    summary
# Counts say whether a link is present. They do not say whether it is correct.

source("R/coverage.R")  # read_whonet, md_table, WHONET_COMMIT

# Both lists repeat a code: Antibiotics.txt has one row per code and disk potency, Organisms.txt
# one row per name (current and old). One row per code: the first filled value of each column.
first_filled <- function(x) { x <- x[x != ""]; if (length(x)) x[1] else "" }
collapse <- function(d, key) {
  out <- do.call(rbind, lapply(split(d, d[[key]]), function(g) vapply(g, first_filled, "")))
  as.data.frame(out, stringsAsFactors = FALSE, check.names = FALSE)
}
# Codes whose rows carry more than one value in a column.
disagree <- function(d, key, col) {
  n <- tapply(d[[col]][d[[col]] != ""], d[[key]][d[[col]] != ""], function(x) length(unique(x)))
  names(n)[n > 1]
}

GROUP_COLUMNS <- c("FAMILY_CODE", "GENUS_CODE", "GENUS_GROUP", "SPECIES_GROUP", "SEROVAR_GROUP")

# Number of entries in Organisms.txt that belong to a group code.
members <- function(org, code, type) {
  if (type %in% GROUP_COLUMNS) return(sum(org[[type]] == code))
  if (type == "ANAEROBE") return(sum(org$ANAEROBE == "X"))
  # Our reading of AN+ and AN-: anaerobes with that SUBKINGDOM_CODE (Gram stain).
  if (type == "ANAEROBE+SUBKINGDOM_CODE")
    return(sum(org$ANAEROBE == "X" & org$SUBKINGDOM_CODE == substr(code, 3, 3)))
  NA_integer_
}

span <- function(d, by) {
  g <- split(d, d[[by]])
  data.frame(code = names(g),
             rows = vapply(g, nrow, 1L),
             guidelines = vapply(g, function(x) paste(sort(unique(x$GUIDELINES)), collapse = " "), ""),
             year_min = vapply(g, function(x) min(x$YEAR), 1L),
             year_max = vapply(g, function(x) max(x$YEAR), 1L), row.names = NULL)
}

link_drugs <- function(d, abx) {
  out <- span(d, "WHONET_ABX_CODE")
  m <- match(out$code, abx$WHONET_ABX_CODE)
  get <- function(col) ifelse(is.na(m), "", abx[[col]][m])
  data.frame(WHONET_ABX_CODE = out$code, ANTIBIOTIC = get("ANTIBIOTIC"), in_list = !is.na(m),
             ATC_CODE = get("ATC_CODE"), LOINCMIC = get("LOINCMIC"), LOINCDISK = get("LOINCDISK"),
             out[c("rows", "guidelines", "year_min", "year_max")])
}

link_organisms <- function(d, org) {
  d$k <- paste(d$ORGANISM_CODE, d$ORGANISM_CODE_TYPE, sep = "\r")
  out <- span(d, "k")
  code <- sub("\r.*", "", out$code); type <- sub(".*\r", "", out$code)
  single <- type == "WHONET_ORG_CODE"
  # A group code has no row of its own; most genus codes have a "sp." row under the same
  # code in lower case, which carries the identifiers of the genus.
  m <- match(ifelse(single, code, tolower(code)), org$WHONET_ORG_CODE)
  get <- function(col) ifelse(is.na(m), "", org[[col]][m])
  data.frame(ORGANISM_CODE = code, ORGANISM_CODE_TYPE = type, ORGANISM = get("ORGANISM"),
             own_row = !is.na(m), TAXONOMIC_STATUS = get("TAXONOMIC_STATUS"),
             SCT_CODE = get("SCT_CODE"), GBIF_TAXON_ID = get("GBIF_TAXON_ID"),
             members = ifelse(single, NA, mapply(members, code, type, MoreArgs = list(org = org))),
             out[c("rows", "guidelines", "year_min", "year_max")])
}

link_by_year <- function(d, drugs, orgs) {
  dm <- match(d$WHONET_ABX_CODE, drugs$WHONET_ABX_CODE)
  om <- match(paste(d$ORGANISM_CODE, d$ORGANISM_CODE_TYPE), paste(orgs$ORGANISM_CODE, orgs$ORGANISM_CODE_TYPE))
  loinc <- ifelse(d$TEST_METHOD == "MIC", drugs$LOINCMIC[dm], drugs$LOINCDISK[dm])
  id <- orgs$SCT_CODE[om] != "" | orgs$GBIF_TAXON_ID[om] != ""
  group <- !id & !is.na(orgs$members[om]) & orgs$members[om] > 0
  all <- d$ORGANISM_CODE_TYPE == "ALL"
  flags <- data.frame(rows = 1L, drug_atc = drugs$ATC_CODE[dm] != "", test_loinc = loinc != "",
                      organism_id = id, organism_member_list_only = group, organism_all = all,
                      organism_unresolved = !id & !group & !all)
  stopifnot(!anyNA(flags))
  out <- aggregate(flags, d[c("GUIDELINES", "YEAR")], sum)
  out[order(out$GUIDELINES, out$YEAR), ]
}

if (sys.nframe() == 0) {
  d <- read_whonet("sources/whonet/Breakpoints.txt")
  abx_rows <- read_tsv("sources/whonet/Antibiotics.txt")
  org_rows <- read_tsv("sources/whonet/Organisms.txt")
  org_rows <- org_rows[order(org_rows$TAXONOMIC_STATUS != "C"), ]  # current name first
  abx <- collapse(abx_rows, "WHONET_ABX_CODE")
  org <- collapse(org_rows, "WHONET_ORG_CODE")
  drugs <- link_drugs(d, abx)
  orgs <- link_organisms(d, org)
  by_year <- link_by_year(d, drugs, orgs)
  stopifnot(sum(by_year$rows) == nrow(d), sum(drugs$rows) == nrow(d), sum(orgs$rows) == nrow(d))

  write.csv(drugs, "out/link_drugs.csv", row.names = FALSE)
  write.csv(orgs, "out/link_organisms.csv", row.names = FALSE)
  write.csv(by_year, "out/link_by_year.csv", row.names = FALSE)

  single <- orgs[orgs$ORGANISM_CODE_TYPE == "WHONET_ORG_CODE", ]
  groups <- orgs[!(orgs$ORGANISM_CODE_TYPE %in% c("WHONET_ORG_CODE", "ALL")), ]
  list_codes <- function(x) if (length(x) == 0) "none" else toString(sort(ifelse(x == "", "(blank)", x)))
  totals <- do.call(rbind, lapply(split(by_year, by_year$GUIDELINES), function(g) {
    s <- colSums(g[-(1:2)])
    data.frame(Guideline = g$GUIDELINES[1], Rows = s[["rows"]],
               `Drug has ATC` = s[["drug_atc"]], `Test has LOINC` = s[["test_loinc"]],
               `Organism has SNOMED CT or GBIF` = s[["organism_id"]],
               `Organism is a member list only` = s[["organism_member_list_only"]],
               `Organism is ALL` = s[["organism_all"]],
               `Organism unresolved` = s[["organism_unresolved"]], check.names = FALSE)
  }))
  group_types <- do.call(rbind, lapply(split(groups, groups$ORGANISM_CODE_TYPE), function(g)
    data.frame(Type = g$ORGANISM_CODE_TYPE[1], Codes = nrow(g),
               `With SNOMED CT or GBIF` = sum(g$SCT_CODE != "" | g$GBIF_TAXON_ID != ""),
               `With members in Organisms.txt` = sum(g$members > 0, na.rm = TRUE), Rows = sum(g$rows),
               check.names = FALSE)))
  lines <- c(
    "# Link audit of WHONET's Breakpoints.txt",
    "",
    sprintf("Files: AMRIE commit %s (Breakpoints.txt, Antibiotics.txt, Organisms.txt; hashes in the Makefile).", WHONET_COMMIT),
    "Human breakpoints of CLSI and EUCAST. A link is counted when the field is filled in WHONET's",
    "own list; whether the code is the right one was not checked.",
    sprintf("Antibiotics.txt: %d rows, %d codes (one row per code and disk potency). Organisms.txt: %d rows,",
            nrow(abx_rows), nrow(abx), nrow(org_rows)),
    sprintf("%d codes (one row per name, current and old). A code counts as linked when any of its rows has", nrow(org)),
    "the field; for organisms the row of the current name comes first.",
    "",
    "## Rows", "",
    "`Test has LOINC`: the drug has a LOINC code for the method of the row (MIC or disk).",
    "`Member list only`: a group code without an identifier of its own, defined by the entries of",
    "Organisms.txt that carry it. `ALL`: rows for all organisms, no link needed.", "",
    md_table(totals), "",
    "## Drug codes", "",
    sprintf("In use: %d. Not in Antibiotics.txt: %s.", nrow(drugs), list_codes(drugs$WHONET_ABX_CODE[!drugs$in_list])),
    sprintf("In the list without ATC: %d (%s).", sum(drugs$in_list & drugs$ATC_CODE == ""),
            list_codes(drugs$WHONET_ABX_CODE[drugs$in_list & drugs$ATC_CODE == ""])),
    sprintf("In the list without a LOINC MIC code: %d. Without a LOINC disk code: %d.",
            sum(drugs$in_list & drugs$LOINCMIC == ""), sum(drugs$in_list & drugs$LOINCDISK == "")),
    sprintf("Codes whose rows give more than one ATC code: %s.", list_codes(disagree(abx_rows, "WHONET_ABX_CODE", "ATC_CODE"))),
    "Per code: `link_drugs.csv`.", "",
    "## Organism codes: single organisms", "",
    sprintf("In use: %d. Not in Organisms.txt: %s.", nrow(single), list_codes(single$ORGANISM_CODE[!single$own_row])),
    sprintf("Without SNOMED CT: %d. Without GBIF: %d. Without either: %d (%s).",
            sum(single$own_row & single$SCT_CODE == ""), sum(single$own_row & single$GBIF_TAXON_ID == ""),
            sum(single$own_row & single$SCT_CODE == "" & single$GBIF_TAXON_ID == ""),
            list_codes(single$ORGANISM_CODE[single$own_row & single$SCT_CODE == "" & single$GBIF_TAXON_ID == ""])),
    sprintf("Only under an old name (no row with TAXONOMIC_STATUS C): %d.", sum(single$own_row & single$TAXONOMIC_STATUS != "C")),
    sprintf("In the whole list, codes whose rows give more than one SNOMED CT code: %d; more than one GBIF ID: %d.",
            length(disagree(org_rows, "WHONET_ORG_CODE", "SCT_CODE")), length(disagree(org_rows, "WHONET_ORG_CODE", "GBIF_TAXON_ID"))),
    "", "## Organism codes: groups", "",
    "The identifiers of a group come from the entry with the same code in lower case, where one",
    "exists (for a genus code, the \"sp.\" entry of the genus).", "",
    md_table(group_types), "",
    "Per code: `link_organisms.csv`. Per guideline and year: `link_by_year.csv`.")
  writeLines(lines, "out/link_coverage.md")
  cat("wrote out/link_*.csv and out/link_coverage.md\n")
}
