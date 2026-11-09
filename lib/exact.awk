# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# exact.awk -- CIDRs that appear in more than one ASN file.
# Input : raw.tsv (asn slug cidr first last len), sorted by cidr then asn
# Output: exact.tsv (asn_a asn_b shared_cidr_count)

BEGIN { FS = OFS = "\t"; cidr = ""; n = 0 }

function flush_group(   i, j, a, b, k) {
    if (n < 2) return
    for (i = 1; i <= n; i++) {
        for (j = i + 1; j <= n; j++) {
            a = list[i] + 0; b = list[j] + 0
            if (a == b) continue
            if (a < b) k = a "|" b
            else       k = b "|" a
            if (!(k in count)) { count[k] = 0; lo[k] = (a < b ? a : b); hi[k] = (a < b ? b : a) }
            count[k]++
        }
    }
}

$3 != cidr {
    flush_group()
    cidr = $3
    n = 0
    split("", seen)
}

{
    if (!($1 in seen)) { seen[$1] = 1; list[++n] = $1 + 0 }
}

END {
    flush_group()
    for (k in count) print lo[k], hi[k], count[k]
}
