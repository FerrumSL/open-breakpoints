Original guideline documents go here, unchanged. They are not committed (see `.gitignore`).
Each one gets a row in `data/sources.tsv` with its URL, version, retrieval date and SHA-256.

`whonet/` holds pinned copies of WHONET's `Breakpoints.txt`, `Antibiotics.txt` and
`Organisms.txt` (AMRIE commit 69de201). `make whonet` and `make whonet-lists` download them and
check their SHA-256 against the Makefile.
