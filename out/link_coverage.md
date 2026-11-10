# Link audit of WHONET's Breakpoints.txt

Files: AMRIE commit 69de201 (Breakpoints.txt, Antibiotics.txt, Organisms.txt; hashes in the Makefile).
Human breakpoints of CLSI and EUCAST. A link is counted when the field is filled in WHONET's
own list; whether the code is the right one was not checked.
Antibiotics.txt: 565 rows, 401 codes (one row per code and disk potency). Organisms.txt: 2978 rows,
2380 codes (one row per name, current and old). A code counts as linked when any of its rows has
the field; for organisms the row of the current name comes first.

## Rows

`Test has LOINC`: the drug has a LOINC code for the method of the row (MIC or disk).
`Member list only`: a group code without an identifier of its own, defined by the entries of
Organisms.txt that carry it. `ALL`: rows for all organisms, no link needed.

| Guideline | Rows | Drug has ATC | Test has LOINC | Organism has SNOMED CT or GBIF | Organism is a member list only | Organism is ALL | Organism unresolved |
| --- | --- | --- | --- | --- | --- | --- | --- |
| CLSI | 21148 | 21048 | 20557 | 19779 | 1321 | 0 | 48 |
| EUCAST | 15381 | 15112 | 14571 | 13139 | 1429 | 476 | 337 |

## Drug codes

In use: 147. Not in Antibiotics.txt: (blank), CFC, FIX, ROX.
In the list without ATC: 7 (AZA, CZA, FPE, GEP, RXT, RZF, SUD).
In the list without a LOINC MIC code: 21. Without a LOINC disk code: 23.
Codes whose rows give more than one ATC code: SDM.
Per code: `link_drugs.csv`.

## Organism codes: single organisms

In use: 122. Not in Organisms.txt: BSB, NME.
Without SNOMED CT: 11. Without GBIF: 12. Without either: 4 (bab, bcn, bsu, bvu).
Only under an old name (no row with TAXONOMIC_STATUS C): 0.
In the whole list, codes whose rows give more than one SNOMED CT code: 0; more than one GBIF ID: 5.

## Organism codes: groups

The identifiers of a group come from the entry with the same code in lower case, where one
exists (for a genus code, the "sp." entry of the genus).

| Type | Codes | With SNOMED CT or GBIF | With members in Organisms.txt | Rows |
| --- | --- | --- | --- | --- |
|  | 1 | 0 | 0 | 39 |
| ANAEROBE | 1 | 1 | 1 | 389 |
| ANAEROBE+SUBKINGDOM_CODE | 2 | 2 | 2 | 538 |
| FAMILY_CODE | 1 | 0 | 1 | 2374 |
| GENUS_CODE | 52 | 51 | 51 | 14159 |
| GENUS_GROUP | 1 | 1 | 1 | 805 |
| SEROVAR_GROUP | 3 | 3 | 3 | 1022 |
| SPECIES_GROUP | 11 | 7 | 10 | 2298 |

Per code: `link_organisms.csv`. Per guideline and year: `link_by_year.csv`.
