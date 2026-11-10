"""First extraction: EUCAST breakpoint table (.xls, versions 2.0 to 7.1) to one row per drug line.

Usage: python extract/eucast.py <workbook.xls> <out.tsv>

Every cell is written as printed, split into the main text and its superscript footnote marks
(the split uses the font information of the workbook). Nothing is interpreted here. The second,
independent extraction reads the PDF (R/extract_eucast_pdf.R); R/compare_extractions.R compares
the two.
"""
import csv
import sys

import xlrd

SKIP_SHEETS = {"Content", "Notes", "Changes"}
FIELDS = ["label", "mic_s", "mic_r", "disk", "zone_s", "zone_r"]


def split_cell(wb, sh, r, c):
    """Return (main text, superscript text) of one cell."""
    cell = sh.cell(r, c)
    if cell.ctype == xlrd.XL_CELL_NUMBER:
        v = cell.value
        return (str(int(v)) if v == int(v) else repr(v)), ""
    if cell.ctype != xlrd.XL_CELL_TEXT:
        return "", ""
    text = cell.value
    runs = sh.rich_text_runlist_map.get((r, c), [])
    fonts = [wb.font_list[wb.xf_list[cell.xf_index].font_index]]
    fonts += [wb.font_list[f] for _, f in runs]
    starts = [0] + [p for p, _ in runs] + [len(text)]
    main = sup = ""
    for i, font in enumerate(fonts):
        part = text[starts[i]:starts[i + 1]]
        if font.escapement == 1:
            sup += part
        else:
            main += part
    return " ".join(main.split()), "".join(sup.split())


def rows_of_sheet(wb, sh):
    """Yield one dict per drug line. Sheets have 7 columns (MIC and disk) or 4 (MIC only)."""
    has_disk = sh.ncols >= 7
    cols = [0, 1, 2, 3, 4, 5] if has_disk else [0, 1, 2]
    group = ""
    for r in range(sh.nrows):
        cells = [split_cell(wb, sh, r, c) for c in cols]
        label, first = cells[0][0], cells[1][0]
        if first.startswith("MIC breakpoint"):
            group = label
            continue
        if not group or not label or not any(main for main, _ in cells[1:]):
            continue
        row = {"sheet": sh.name, "row": r + 1, "group": group}
        for name, (main, sup) in zip(FIELDS, cells):
            row[name], row[name + "_sup"] = main, sup
        yield row


def main(src, out):
    wb = xlrd.open_workbook(src, formatting_info=True)
    names = ["sheet", "row", "group"] + [f + s for f in FIELDS for s in ("", "_sup")]
    with open(out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, names, delimiter="\t", restval="", lineterminator="\n",
                           quoting=csv.QUOTE_NONE, quotechar=None, escapechar=None)
        w.writeheader()
        for sh in wb.sheets():
            if sh.name not in SKIP_SHEETS:
                w.writerows(rows_of_sheet(wb, sh))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
