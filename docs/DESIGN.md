# Design

## Principles

1. Follow WHONET's example: same columns, codes and conventions; our additions never change
   what WHONET's software reads.
2. Open to everyone, easy to use: plain text files, readable diffs, no software needed to use
   the result.
3. Accuracy before coverage: one fully checked year is worth more than five unchecked ones.
   "100 % accurate" cannot be promised by any process, so the rule is: every value is traceable
   and checked twice, every error that is found is corrected and recorded in `CHANGELOG.md`
   (to be started with the first real data).

## Decisions (2026-11-10)

| Topic | Decision | Reason |
|---|---|---|
| Languages | Python for the first extraction (Excel); R for the second extraction (PDF), comparison, encoding, validation and export | Python's `xlrd` reads the fonts of the workbook, which separate footnote marks from values. R is common among people who work with resistance data. Two toolchains give two independent extractions. Users of the tables need neither |
| Data model | Own schema, version 0 = WHONET's 22 columns plus `SOURCE_ID`, `SOURCE_LOCATOR`, `STATUS` | Base for a shared format later, without leaving WHONET's format now |
| Guard 1 | Export must reproduce WHONET's 22 columns exactly. Tested on the fixture and on WHONET's whole file, which comes back with identical bytes | The export step must never alter a value |
| Guard 2 | No renaming or retyping of WHONET columns in version 0 | Avoids fighting WHONET's conventions before they are agreed |
| Storage | One TSV per guideline and year | Small pull requests, readable diffs |
| Validation | Declarative schema (`schema/`) plus coded rules (`R/validate.R`) | Simple rules readable by non-programmers; cross-row rules in code |
| Mappings | SSSOM TSV, planned; no mapping file exists yet | Existing standard for mapping tables, plain text |
| Pipeline | Makefile | No extra dependency, works for both languages |
| Sorting | Fixed to the C locale in `R/common.R` | Generated files are the same on every machine |
| Tests | Base R `stopifnot` in `tests/run.R` | Enough for now; move to testthat when the suite grows |

## How a EUCAST year is built

1. `extract/eucast.py` reads the Excel workbook and writes every drug line as printed, with
   footnote marks separated from values by the font information.
2. `R/extract_eucast_pdf.R` reads the PDF independently. Value lines that it cannot read as a
   drug line (the drug name is on another line) are written to a file and counted in the report.
3. `R/compare_extractions.R` compares the two cell by cell. Differences go to a person.
4. `R/encode_eucast.R` applies WHONET's conventions (documented at the top of that file) and
   writes rows and a list of flagged cases. It stops on anything it has no rule for.
5. `R/report_eucast.R` runs two more checks: the same method must reproduce rows WHONET already
   has for the year, and every difference from WHONET's rows for the next year must match a
   revision that EUCAST lists.
6. People: comparison with the source, then clinical review of the flagged cases.

Limits found so far: a footnote mark that the workbook does not format as superscript
("Ciprofloxacin1") is invisible to both extractions and is caught only at step 4. The same
would hold for a value: the split between a value and its footnote mark comes from the
workbook's fonts alone, and the PDF text cannot confirm it ("641" is 64 with footnote 1). The
comparison with the next year and the check by people cover this, and the validator rule for
MIC values off the doubling scale catches most such cases (81 for 8 with footnote 1, but not 16
for 1 with footnote 6). Workbooks from v3.1 are password-protected. Tables with species-specific
lines (Staphylococcus, streptococci and others) need rules that do not exist yet.

## Link audit

`make links` runs `R/link_coverage.R`. It reads the pinned `Breakpoints.txt`, `Antibiotics.txt`
and `Organisms.txt` (AMRIE commit 69de201, hashes in the Makefile) and counts, for the human
CLSI and EUCAST rows, how many already have a drug with an ATC code, a LOINC code for the test
method, and an organism with a SNOMED CT or GBIF identifier. Output: `out/link_coverage.md`,
`out/link_drugs.csv`, `out/link_organisms.csv`, `out/link_by_year.csv`.

Both lists repeat codes: `Antibiotics.txt` has one row per drug code and disk potency (565 rows,
401 codes), `Organisms.txt` one row per name, current and old (2978 rows, 2380 codes). The
audit keeps one row per code: any row of a code may carry the link, and for organisms the row
of the current name comes first. A group code takes the identifiers of the entry with the same
code in lower case (for a genus, its "sp." entry); without one it counts as a member list
(the entries of `Organisms.txt` that carry the code). `EBC` is such a list: 383 organisms, one
list for all years.

The audit counts whether a field is filled, not whether the code is correct. The totals were
counted a second time with a separate script and agree.

## Row status

`draft` (extracted) -> `checked` (two extractions agree, and two people have each compared the
row with the source without seeing the other's result) -> `reviewed` (judgment calls decided by
a clinical reviewer). Only `reviewed` rows are proposed to WHONET.

## Open questions

- Licence for code and for data: not decided; the README asks people to ask before reuse. Rights
  to publish CLSI values: ask WHONET before any CLSI row
  is prepared. Until then EUCAST only.
- Row key (guideline, year, method, potency, organism, type, host, site, test): not unique in
  WHONET's own file. 912 rows share a key with another row (commit 69de201), among them 16
  human EUCAST rows: exact duplicates, and pairs with different values where a site seems to
  be missing (2013, M. catarrhalis, cefuroxime). The duplicate rule stays strict for our rows.
- MIC values in WHONET's file that are off the doubling scale (`make scale`, list in
  `out/scale_whonet.csv`): in the human CLSI and EUCAST rows 0.0001 (508 rows), 129, 513 and
  1025 (120 rows); the whole file has 684 such values, the rest in SFM and NEO rows. Ask WHONET
  for the rule before a table needs them. Two rows have 0.32 where the source prints 0.032
  (EUCAST 2011, enterococci, trimethoprim and trimethoprim-sulfamethoxazole): to report to
  WHONET.
- Found by the link audit in WHONET's files, to ask as questions: `NME` used as a single
  organism code in EUCAST 2013 to 2019 (77 rows; the list has `nme`); `BSB` in EUCAST 2013
  (4 rows, not in the list); 39 EUCAST 2021 rows with code `Gen` and an empty code type; 5 rows
  (EUCAST 2015 to 2019, `mtu`) with an empty drug code; drug SDM with two ATC codes.
- Group codes such as `EBC` have one member list for all years. Does a group need a date?
- Allowed values for `TEST_METHOD`, `ORGANISM_CODE_TYPE`, `BREAKPOINT_TYPE`, `HOST`: take them
  from WHONET's file and add them to the schema as `enum`.
- Which old EUCAST versions exist as Excel and which as PDF only.
- Planned validator rules: listed at the end of `check_rules` in `R/validate.R`.
- Dependency pinning (`renv`, `uv` lock) once the dependencies settle.
