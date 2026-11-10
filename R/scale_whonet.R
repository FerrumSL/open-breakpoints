# MIC values in WHONET's Breakpoints.txt that are off the doubling scale.
# Usage: Rscript R/scale_whonet.R   (after `make whonet`)
# Uses the scale of the validator (MIC_SCALE in R/validate.R) on every row of the file.
# Writes out/scale_whonet.csv, one line per value, and prints the count per value.
# An off-scale value is a question for WHONET, not always an error: some follow a convention.

source("R/validate.R")

d <- read_tsv("sources/whonet/Breakpoints.txt")
out <- do.call(rbind, lapply(c("S", "R"), function(col) {
  bad <- d$TEST_METHOD == "MIC" & d[[col]] != "" & !(d[[col]] %in% MIC_SCALE)
  cbind(d[bad, c("GUIDELINES", "YEAR", "BREAKPOINT_TYPE", "ORGANISM_CODE", "WHONET_TEST")],
        column = rep(col, sum(bad)), value = d[[col]][bad])
}))
out <- out[order(as.numeric(out$value), out$GUIDELINES, out$YEAR), ]
dir.create("out", showWarnings = FALSE)
write.csv(out, "out/scale_whonet.csv", row.names = FALSE)
print(table(value = out$value, column = out$column))
