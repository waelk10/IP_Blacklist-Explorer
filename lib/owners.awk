# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# owners.awk -- group ASNs that share an operator slug (e.g. contabo, censys).
# Input : asn_stats.tsv (rank asn slug aliases raw merged addresses share ...)
# Output: owner asn_count addresses share prefixes asn_list

BEGIN { FS = OFS = "\t" }

{
    key = tolower($3)
    if (key == "") next
    if (!(key in n)) {
        n[key] = 0
        share[key] = 0
        addr[key] = 0
        pref[key] = 0
        names[key] = ""
        order[++m] = key
    }
    n[key]++
    addr[key] += $7 + 0
    share[key] += $8 + 0
    pref[key] += $6 + 0
    label = "AS" $2 " " $3
    names[key] = (names[key] == "" ? label : names[key] ", " label)
}

END {
    for (i = 1; i <= m; i++) {
        k = order[i]
        print k, n[k], sprintf("%.0f", addr[k]), sprintf("%.4f", share[k]), pref[k], names[k]
    }
}
