# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# merge.awk -- collapse each ASN's CIDR list into disjoint address ranges.
#
# Input : extract.awk output, sorted by asn, start, end
# Output: merged.tsv  asn start end size
#         meta.tsv    asn slug aliases raw merged addresses minlen maxlen
#
# "addresses" is the number of unique IPv4 addresses covered by that ASN
# after overlapping/adjacent CIDRs are merged.  Duplicate CIDRs (same range
# listed twice, or two files for the same ASN) are counted once.

BEGIN {
    OFS = "\t"
    FS = "\t"
}

function flush(   i, aliases, primary, best, bestn) {
    if (asn == "") return
    if (cur_s >= 0) {
        nmerged++
        mstart[nmerged] = cur_s; mend[nmerged] = cur_e
        addresses += cur_e - cur_s + 1
        cur_s = -1
    }
    bestn = -1
    for (i = 1; i <= nslug; i++)
        if (slug_n[i] > bestn) { bestn = slug_n[i]; best = i }
    # choose the most frequently seen slug as the display name
    primary = slug[best]
    aliases = ""
    for (i = 1; i <= nslug; i++) {
        if (slug[i] != primary)
            aliases = (aliases == "" ? slug[i] : aliases "|" slug[i])
    }

    print asn, primary, aliases, raw, nmerged, addresses, minlen, maxlen > meta
    for (i = 1; i <= nmerged; i++)
        print asn, mstart[i], mend[i], mend[i] - mstart[i] + 1 > merged
}

{
    a = $1 + 0
    s = $4 + 0
    e = $5 + 0
    l = $6 + 0

    if (a != asn) {
        flush()
        asn = a
        raw = 0; nmerged = 0; addresses = 0
        minlen = 99; maxlen = -1
        nslug = 0
        split("", slug); split("", slug_n)
        cur_s = -1; cur_e = -1
        split("", seendup)
    }

    # dedupe identical ranges inside one ASN
    if ((s SUBSEP e) in seendup) next
    seendup[s SUBSEP e] = 1

    raw++
    if (l < minlen) minlen = l
    if (l > maxlen) maxlen = l

    # slug bookkeeping
    found = 0
    for (i = 1; i <= nslug; i++) if (slug[i] == $2) { slug_n[i]++; found = 1 }
    if (!found) { nslug++; slug[nslug] = $2; slug_n[nslug] = 1 }

    if (cur_s < 0) {
        cur_s = s; cur_e = e
    } else if (s <= cur_e + 1) {
        if (e > cur_e) cur_e = e
    } else {
        nmerged++
        mstart[nmerged] = cur_s; mend[nmerged] = cur_e
        addresses += cur_e - cur_s + 1
        cur_s = s; cur_e = e
    }
}

END {
    flush()
}
