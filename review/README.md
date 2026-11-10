# Review files

For each rebuilt table:

| File | Content |
|---|---|
| `EUCAST_<year>_report.md` | The automatic checks and their results. Generated; do not edit |
| `EUCAST_<year>_flags.tsv` | The cases that need a clinical reviewer: footnotes, lines without numbers, infection sites, species limits. Generated, then filled in by the reviewer |
| `EUCAST_<year>_questions.md` | Questions on WHONET's conventions that the draft could not settle |
| `check/..._check_sheet.csv` | One line per draft row, for the people who compare the rows with the source document |

Columns of the flags file: `sheet`, `row` and `label` locate the line in the source; `what` is
what the source says; `proposed` is how the draft encodes it; `reviewer`, `decision` and `date`
are filled in by the reviewer. Only this list goes to the clinical reviewer, not the whole
table.

Columns of the check sheet: the draft values (`draft_S`, `draft_I`, `draft_R`) next to empty
fields for the values as printed (`printed_S`, `printed_R`), a verdict and a comment. Each
person fills in a copy without seeing the other's.
