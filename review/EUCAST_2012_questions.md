# EUCAST 2012 draft: questions on conventions

For WHONET (Adam). Seven questions. The first two decide how most of the special lines are
written; the values themselves do not depend on them.

The draft follows WHONET's EUCAST 2013 rows, the nearest year. Reading the later years of the
file showed that 2013 is not how the same source lines are written from 2014 on. We did not
want to guess which one is wanted for rebuilt rows, so the draft stays with 2013 and the
differences are listed here.

## 1. Which year's layout should rebuilt 2012 rows follow?

| Source line (v2.0) | WHONET 2013 | WHONET 2014 to 2019 | Draft |
| --- | --- | --- | --- |
| Cefoxitin (screen): zone breakpoint only, MIC "NA", ECOFF 8 mg/L in a footnote | DISK row without a site, and an MIC row with S = 8 only | DISK row with site "Screen", no MIC row | DISK row without a site |
| Cefuroxime | CXM, no site | CXM, site "Intravenous" | CXM, no site |
| Cefuroxime axetil (uncomplicated UTI only) | Twice, as CXA and as CXM, both with the UTI site | CXM with the UTI site | CXA with the UTI site |
| Fosfomycin iv, and Fosfomycin-trometamol (uncomplicated UTI only), same values | One FOS row, no site | Two FOS rows: no site, and the UTI site | Two FOS rows, as 2014 |
| Ceftibuten (UTI only) | Site "Uncomplicated urinary tract infection" | Same | Same |

The source prints "Cefuroxime" and "Cefuroxime axetil" in v2.0, and "Cefuroxime iv" and
"Cefuroxime oral" from v3.1 (2013).

If the layout of 2014 and later is wanted, three things change in the draft: cefoxitin gets the
site "Screen", cefuroxime axetil becomes CXM, and cefuroxime gets the site "Intravenous".

## 2. Species limits that are given only in a footnote

In v2.0 four breakpoints are limited to some species by a footnote, not in the drug line.

| Drug | Footnote | WHONET 2013 | WHONET 2014 to 2019 | WHONET later | Draft |
| --- | --- | --- | --- | --- | --- |
| Mecillinam | E. coli, Klebsiella spp. and P. mirabilis only | eco, kpn, pmi | EBC | from 2021: E. coli, KL-, pmi and three more genera | eco, kpn, pmi |
| Cefuroxime (MIC) | E. coli, P. mirabilis and Klebsiella spp. only | EBC | EBC | EBC | EBC |
| Nitrofurantoin | E. coli only | EBC | EBC | from 2020: E. coli | EBC |
| Tigecycline (disk) | Zone breakpoints validated for E. coli only | EBC | EBC | from 2020: E. coli | EBC |

EUCAST prints the species in the drug line itself from v9.0 (2019), for example
"Nitrofurantoin (uncomplicated UTI only), E. coli".

Should rebuilt rows keep the family row when the limit is only in a footnote, or get rows for
the named species? If species rows: is Klebsiella the genus (KL-) and not kpn?

## 3. REFERENCE_TABLE and REFERENCE_SEQUENCE

The existing EUCAST 2012 rows have an empty REFERENCE_TABLE; the 2013 rows have the sheet name
("Enterobacteriaceae"). The draft follows 2013. Which is wanted for new 2012 rows?
REFERENCE_SEQUENCE is left empty in the draft. How is it assigned?

## 4. Low MIC values

WHONET's rows spell S values as 0.032 and 0.125 where EUCAST prints 0.03 and 0.12, and R values
as 0.12 (for "R > 0.06"). What is the rule? The Enterobacteriaceae table has no value below
0.5, so the draft is not affected; other tables are.

## 5. Ticarcillin-clavulanate disk

The source prints 75-10; WHONET's label is 75/10-15µg. The draft uses WHONET's label.

## 6. DATE_ENTERED

The draft uses the day the rows were first generated (2026-11-10). Existing rows carry
2021-01-01.

## 7. Lines without numbers

For "-", "NA", "IE" and "Note" no row is written. Is that right for "IE"?

## Checked

Against the v3.1 PDF (valid from 2013-02-11) on 2026-11-09 and again on 2026-11-10: the three
values that differ from WHONET's 2013 rows (piperacillin, cefalexin and aztreonam zone
diameters) are the three that EUCAST's v3.1 list of changes names for this table ("Revised
breakpoints: Piperacillin, cefalexin and aztreonam (zone)"), and the v3.1 values (zones 20/17,
14/14 and 24/21) give WHONET's 2013 rows under the same conversion rules. Ceftaroline, present
only in 2013, is not in the v2.0 table.

Note for later years: the EUCAST v3.1 workbook (2013) is password-protected, so its first
extraction cannot use the same reader; the PDF extraction works on it.
