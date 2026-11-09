# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# union.awk -- size of the union of all ASN ranges.
# Input: merged.tsv sorted by start (asn start end size).
# Output: one line "addresses ranges" on stdout.

BEGIN { FS = OFS = "\t"; cur = -1; n = 0 }

{
    s = $2 + 0; e = $3 + 0
    if (cur < 0) {
        cur = s; end = e
    } else if (s <= end + 1) {
        if (e > end) end = e
    } else {
        total += end - cur + 1
        n++
        cur = s; end = e
    }
}

END {
    if (cur >= 0) { total += end - cur + 1; n++ }
    print total, n
}
