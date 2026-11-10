.PHONY: check test validate whonet whonet-lists coverage links scale eucast-2012 export

# Tests, then validation of every file under data/breakpoints.
check: test validate

test:
	Rscript tests/run.R

validate:
	Rscript R/validate.R data

# --- WHONET's files, pinned to AMRIE commit 69de201. Every download is checked against its hash.

WHONET_BASE = https://raw.githubusercontent.com/WHONET-Development/AMRIE/69de201/Interpretation%20Engine/Resources/

sources/whonet/Breakpoints.txt: SHA = c9c6e72844d144941051e0fa1919ae9698846993d21cce043693d0a25092d202
sources/whonet/Antibiotics.txt: SHA = 55ac3904dde701944346afeed76a5433a1665dbd023d87ab8d1cbe5eadacda31
sources/whonet/Organisms.txt:   SHA = ee5e2c93c9f81ac9d3104bfb0858008b53cf7dc98170370dba3c09fc8705b164

sources/whonet/Breakpoints.txt sources/whonet/Antibiotics.txt sources/whonet/Organisms.txt:
	mkdir -p sources/whonet
	curl -sSL "$(WHONET_BASE)$(notdir $@)" -o $@.part
	echo "$(SHA)  $@.part" | sha256sum -c -
	mv $@.part $@

whonet: sources/whonet/Breakpoints.txt

whonet-lists: sources/whonet/Antibiotics.txt sources/whonet/Organisms.txt

# --- Audits of WHONET's file. Results are written to out/ and are tracked.

# Rows per guideline, year, table and organism -> out/coverage_*
coverage: whonet
	Rscript R/coverage.R

# Outside identifiers (ATC, LOINC, SNOMED CT, GBIF) already present for the codes in use -> out/link_*
links: whonet whonet-lists
	Rscript R/link_coverage.R

# MIC values that are off the doubling scale -> out/scale_whonet.csv
scale: whonet
	Rscript R/scale_whonet.R

# --- EUCAST 2012 (table v2.0): two extractions, comparison, draft rows, checks.
# The source documents are downloaded to sources/eucast/ and checked against data/sources.tsv.

E12 = work/EUCAST_2012
E12_SRC = sources/eucast/Breakpoint_table_v_2.0_120221
E12_URL = https://www.eucast.org/fileadmin/eucast/pdf/Document_Archive/bacteria/breakpoint_tables/Breakpoint_table_v_2.0_120221
# DATE_ENTERED of the draft rows: the day they were first generated. Fixed, so that a new run
# gives the same file.
E12_DATE = 2026-11-10

$(E12_SRC).xls $(E12_SRC).pdf:
	mkdir -p sources/eucast
	curl -sSL -A "Mozilla/5.0" "$(E12_URL)$(suffix $@)" -o $@.part
	grep -q "$$(sha256sum $@.part | cut -d' ' -f1)" data/sources.tsv
	mv $@.part $@

# The comparison exits with status 1 when the extractions differ. The run goes on, because
# R/report_eucast.R repeats the comparison and writes the number of differences into the report.
eucast-2012: whonet $(E12_SRC).xls $(E12_SRC).pdf
	mkdir -p $(E12)
	uv run -q --with xlrd==2.0.2 python -I extract/eucast.py $(E12_SRC).xls $(E12)/xls_cells.tsv
	Rscript R/extract_eucast_pdf.R $(E12_SRC).pdf $(E12)/pdf_cells.tsv
	-Rscript R/compare_extractions.R $(E12)/xls_cells.tsv $(E12)/pdf_cells.tsv $(E12)/differences.tsv
	Rscript R/encode_eucast.R $(E12)/xls_cells.tsv 2012 eucast-2.0-xls $(E12) $(E12_DATE)
	Rscript R/report_eucast.R $(E12) 2012 Enterobacteriaceae 2013

# --- Export one file to WHONET's format: make export FILE=data/breakpoints/EUCAST/2012.tsv
export:
	mkdir -p out
	Rscript R/export_whonet.R $(FILE) out/$(notdir $(basename $(FILE))).txt
