# open-breakpoints

Historical antimicrobial breakpoint tables, rebuilt from the original guideline documents in
the format of WHONET's `Breakpoints.txt`. Every value is traced to its place in the source
document and checked.

**Status: draft.** No row in this repository has been reviewed by a clinical microbiologist or
accepted by WHONET. Do not use the rows for interpretation yet.

## Background

A clinical breakpoint decides whether a measured MIC or zone diameter is reported as
susceptible or resistant. EUCAST and CLSI revise their breakpoints every year, so a result can
only be interpreted, or reinterpreted, with the table that was valid at the time. The tables
are published as documents for people. WHONET maintains an open, machine-readable collection of
them, [`Breakpoints.txt`](https://github.com/WHONET-Development/AMRIE), which WHONET itself and
other software read.

For some early years that file lacks tables, and a row names at most the table it belongs to,
not the document version or the place in it. This repository does three things:

1. It rebuilds missing tables from the original documents, in WHONET's own format.
2. It checks every value: two independent extractions, automatic checks against the rows
   WHONET already has, then comparison with the source by two people. Judgment calls are
   listed for clinical review.
3. It serves as a working example for the question raised in
   [AMRIE issue 27](https://github.com/WHONET-Development/AMRIE/issues/27): a breakpoint
   format that other software can read, with rows tied to their source and to ATC, LOINC,
   SNOMED CT and GBIF.

We are an independent group. We are not part of WHONET, EUCAST, CLSI or the AMR package for R.
Nothing here is agreed with WHONET, and WHONET decides what it adopts.

## What is here

| Result | File |
|---|---|
| EUCAST v2.0 (2012), Enterobacteriaceae: 85 draft rows. WHONET's file has no rows for this table | `data/breakpoints/EUCAST/2012.tsv` |
| The automatic checks on these rows and their results | `review/EUCAST_2012_report.md` |
| 40 cases that need a clinical reviewer (footnotes, infection sites, species limits) | `review/EUCAST_2012_flags.tsv` |
| Seven questions on WHONET's conventions that the draft could not settle | `review/EUCAST_2012_questions.md` |
| Coverage of `Breakpoints.txt`: rows per guideline, year, table and organism | `out/coverage_summary.md`, `out/coverage_*.csv` |
| Link audit: which rows already have ATC, LOINC, SNOMED CT or GBIF identifiers in WHONET's own lists | `out/link_coverage.md`, `out/link_*.csv` |
| MIC values in `Breakpoints.txt` that are off the doubling scale | `out/scale_whonet.csv` |

## Method

A table is built in six steps. Each step is one script, and `make eucast-2012` runs the first
five.

1. **First extraction.** `extract/eucast.py` reads the Excel workbook and writes every drug
   line as printed. Footnote marks are separated from values by the font of the cell.
2. **Second extraction.** `R/extract_eucast_pdf.R` reads the PDF of the same table, with other
   software and without the first result.
3. **Comparison.** `R/compare_extractions.R` compares the two, cell by cell.
4. **Encoding.** `R/encode_eucast.R` applies WHONET's conventions and writes the rows. Every
   case that needed a decision goes to a list for the reviewer. The script stops on a line it
   has no rule for.
5. **Checks against WHONET's rows.** `R/report_eucast.R` applies the same method to tables
   that WHONET already has for the year, and compares the new rows with WHONET's rows for the
   next year.
6. **People.** Two people each compare the rows with the source, without seeing the other's
   result. The flagged cases are listed for clinical review.

Results of the automatic checks for the 2012 table:

- The two extractions agree in all 1085 cells of the four tables in use.
- The method reproduces 56 of 56 rows that WHONET has for *Pseudomonas*, *Acinetobacter* and
  *S. maltophilia* in 2012.
- Of the 85 new rows, 81 equal WHONET's 2013 rows. Three differ, and they are the three
  breakpoints that EUCAST lists as revised in v3.1. One row exists only in the draft.

Step 6 is not finished. The limits of each check are stated in the report.

The conversion rules are documented at the top of `R/encode_eucast.R`, the design decisions and
open questions in `docs/DESIGN.md`.

## Use

```
make check          # tests, and validation of the files in data/
make coverage       # coverage of WHONET's file              -> out/coverage_*
make links          # link audit of WHONET's file            -> out/link_*
make scale          # MIC values off the doubling scale      -> out/scale_whonet.csv
make eucast-2012    # the five automatic steps for the 2012 table -> data/, review/
make export FILE=data/breakpoints/EUCAST/2012.tsv            # -> out/2012.txt, WHONET's format
```

Requirements: R with the package `jsonlite`, `curl`, and for `make eucast-2012` also
[`uv`](https://docs.astral.sh/uv/) and `pdftotext` (poppler). Tested on Linux.

The source documents are not in the repository. The make targets download them and check each
file against a recorded SHA-256: WHONET's files at AMRIE commit 69de201, EUCAST's table from
EUCAST's archive (`data/sources.tsv`).

The exported file has WHONET's 22 columns and nothing else. Reading WHONET's whole
`Breakpoints.txt` and writing it back through the export gives identical bytes; the tests check
this.

## Layout

```
data/breakpoints/<GUIDELINE>/<YEAR>.tsv   the rebuilt rows
data/sources.tsv                          one row per source document: URL, version, SHA-256
schema/      column names, types and allowed values
maps/        sheet -> organism code, drug name -> WHONET antibiotic code
extract/     first extraction (Python)
R/           second extraction, comparison, encoding, report, validator, export, audits
review/      per table: report, flagged cases, questions, check sheet for the people who compare
out/         results of the audits of WHONET's file
tests/       tests and a synthetic fixture
docs/        DESIGN.md: decisions, limits, open questions
sources/     downloaded source documents (not committed)
```

A data file has WHONET's 22 columns, in WHONET's order, and three more: `SOURCE_ID` (the
document), `SOURCE_LOCATOR` (sheet and row in it) and `STATUS` (`draft`, `checked` or
`reviewed`). Only `reviewed` rows are proposed to WHONET.

## Limits

- One table of one year. Tables with species-specific lines (staphylococci, streptococci and
  others) need encoding rules that are not written yet.
- The row layout (sites, organism level, drug codes) follows WHONET's EUCAST 2013 rows.
  WHONET's later years write some lines differently. Which layout is wanted is a question for
  WHONET: `review/EUCAST_2012_questions.md`.
- The audits of WHONET's file count what is present. They do not say whether a value or a code
  is correct.
- EUCAST only. No CLSI rows are prepared until the rights to publish them are clear.

## Licence

Not decided yet. Please ask before reuse: open an issue. The breakpoint values are EUCAST's.

## Contact

Questions, corrections and errors: please open an issue in this repository.
