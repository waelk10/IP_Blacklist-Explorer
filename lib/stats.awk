# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# stats.awk -- per-ASN summary joined with relation totals.
# Input : meta.tsv, edges.tsv
# Output: asn slug aliases raw merged addresses share degree overlap_sum max_jaccard

BEGIN { FS = OFS = "\t" }

FNR == NR {
    asn[++n] = $1 + 0
    slug[$1 + 0] = $2
    alias[$1 + 0] = $3
    raw[$1 + 0] = $4 + 0
    merged[$1 + 0] = $5 + 0
    addr[$1 + 0] = $6 + 0
    next
}

{
    a = $1 + 0; b = $2 + 0
    deg[a]++; deg[b]++
    osum[a] += $3; osum[b] += $3
    if ($4 > mjac[a]) mjac[a] = $4
    if ($4 > mjac[b]) mjac[b] = $4
}

END {
    for (i = 1; i <= n; i++) {
        a = asn[i]
        share = (total > 0 ? 100 * addr[a] / total : 0)
        printf "%d\t%s\t%s\t%d\t%d\t%.0f\t%.6f\t%d\t%.0f\t%.6f\n", \
            a, slug[a], alias[a], raw[a], merged[a], addr[a], share, \
            deg[a] + 0, osum[a] + 0, mjac[a] + 0
    }
}
