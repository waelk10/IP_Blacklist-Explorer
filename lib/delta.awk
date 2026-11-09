# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# delta.awk -- compare this run's asn_stats.tsv with the previous run's.
# Input : previous asn_stats.tsv, current asn_stats.tsv
# Output: asn slug status delta_prefixes delta_addresses delta_share_
#         current_addresses previous_addresses

BEGIN { FS = OFS = "\t" }

FNR == NR {
    p_asn[$2 + 0] = 1
    p_slug[$2 + 0] = $3
    p_raw[$2 + 0] = $5 + 0
    p_addr[$2 + 0] = $7 + 0
    p_share[$2 + 0] = $8 + 0
    next
}

{
    a = $2 + 0
    cur[a] = 1
    dpref = ($5 + 0) - (p_raw[a] + 0)
    daddr = ($7 + 0) - (p_addr[a] + 0)
    dshare = ($8 + 0) - (p_share[a] + 0)
    if (!(a in p_asn)) status = "new"
    else if (dpref == 0 && daddr == 0) status = "steady"
    else if (daddr > 0) status = "grew"
    else status = "shrank"
    if (status != "steady")
        print a, $3, status, dpref, sprintf("%.0f", daddr), sprintf("%.4f", dshare), sprintf("%.0f", $7 + 0), sprintf("%.0f", p_addr[a] + 0)
}

END {
    for (a in p_asn) {
        if (a in cur) continue
        print a, p_slug[a], "lost", -p_raw[a], sprintf("%.0f", -p_addr[a]), sprintf("%.4f", -p_share[a]), 0, sprintf("%.0f", p_addr[a])
    }
}
