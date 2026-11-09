# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# coverage.awk -- attribute service-list addresses to tracked ASNs.
#
# Input : merged.tsv sorted by start (loaded first), then channel files
#         containing IPv4 addresses or CIDRs.
# Output: service_asn.tsv     channel asn hits
#         service_channel.tsv channel total matched percent
#
# The lookup uses the rightmost containing range, which is normally the most
# specific prefix an address appears in.  Overlaps are common in this data,
# so this is an attribution, not a statement of sole ownership.

BEGIN {
    FS = OFS = "\t"
    n = 0
    while ((getline line < merged) > 0) {
        split(line, f, "\t")
        n++
        mstart[n] = f[2] + 0
        mend[n] = f[3] + 0
        masn[n] = f[1] + 0
        maxend[n] = (n > 1 && maxend[n - 1] > mend[n] ? maxend[n - 1] : mend[n])
    }
    close(merged)
}

function to_num(s,   p, o, i) {
    if (split(s, p, "/") > 2) return -1
    if (split(p[1], o, ".") != 4) return -1
    for (i = 1; i <= 4; i++)
        if (o[i] !~ /^[0-9]+$/ || (o[i] + 0) > 255) return -1
    return ((o[1] * 256 + o[2]) * 256 + o[3]) * 256 + o[4]
}

function find_asn(ip,   lo, hi, mid, pos, j) {
    lo = 1; hi = n; pos = 0
    while (lo <= hi) {
        mid = int((lo + hi) / 2)
        if (mstart[mid] <= ip) { pos = mid; lo = mid + 1 }
        else hi = mid - 1
    }
    if (pos == 0 || maxend[pos] < ip) return 0
    j = pos
    while (j >= 1 && maxend[j] >= ip) {
        if (mend[j] >= ip) return masn[j]
        j--
    }
    return 0
}

{
    np = split(FILENAME, path, "/")
    ch = path[np]
    if (!(ch in total)) { total[ch] = 0; matched[ch] = 0 }

    line = $0
    sub(/\r$/, "", line)
    gsub(/^[ \t]+|[ \t]+$/, "", line)
    if (line == "" || line ~ /^#/) next

    ip = to_num(line)
    if (ip < 0) next
    total[ch]++
    a = find_asn(ip)
    if (a > 0) {
        matched[ch]++
        hits[ch SUBSEP a]++
    }
}

END {
    for (k in hits) {
        split(k, p, SUBSEP)
        print p[1], p[2], hits[k]
    }
    for (ch in total) {
        pct = (total[ch] > 0 ? 100 * matched[ch] / total[ch] : 0)
        print ch, total[ch], matched[ch], sprintf("%.1f", pct) > chfile
    }
}
