# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# edges.awk -- derive ASN-to-ASN relations from shared address space.
#
# Input : merged.tsv sorted by start (asn start end size)
#         meta.tsv  (for ASN sizes)
#         exact.tsv (shared CIDR counts)
# Output: edges.tsv
#         asn_a asn_b overlap_addresses jaccard shared_prefix_pairs
#         a_inside_b b_inside_a shared_cidrs
#
# "overlap_addresses" sums, over every overlapping pair of merged ranges,
# the size of the intersection.  It is a weight, not a unique-area count
# (the dashboard's overlap KPI is computed separately by depth.awk).
# "a_inside_b" is the share of A's listed space that sits inside a single
# B range; a high value hints at leased / downstream space.

BEGIN {
    FS = OFS = "\t"
    na = 0
    while ((getline line < meta) > 0) {
        split(line, f, "\t")
        size[f[1] + 0] = f[6] + 0
        slug[f[1] + 0] = f[2]
    }
    close(meta)
    while ((getline line < exact) > 0) {
        split(line, f, "\t")
        a = f[1] + 0; b = f[2] + 0
        k = (a < b ? a "|" b : b "|" a)
        ex[k] = f[3] + 0
    }
    close(exact)
}

function pairkey(a, b) {
    return (a < b ? a "|" b : b "|" a)
}

{
    asn = $1 + 0
    s = $2 + 0
    e = $3 + 0

    # drop ranges that have already ended (swap-remove, order is irrelevant)
    i = 1
    while (i <= na) {
        if (aend[i] < s) {
            aasn[i] = aasn[na]; astart[i] = astart[na]; aend[i] = aend[na]
            na--
        } else {
            i++
        }
    }

    for (j = 1; j <= na; j++) {
        if (aasn[j] == asn) continue
        k = pairkey(asn, aasn[j])
        if (!(k in seen)) {
            seen[k] = 1
            lo[k] = (asn < aasn[j] ? asn : aasn[j])
            hi[k] = (asn < aasn[j] ? aasn[j] : asn)
        }
        ov[k] += (aend[j] < e ? aend[j] : e) - s + 1
        cnt[k]++
        if (aend[j] >= e) cont[asn ">" aasn[j]] += e - s + 1
        if (astart[j] == s && aend[j] <= e)
            cont[aasn[j] ">" asn] += aend[j] - astart[j] + 1
    }

    na++
    aasn[na] = asn; astart[na] = s; aend[na] = e
}

END {
    for (k in seen) {
        a = lo[k]; b = hi[k]
        if (!(k in ov) && !(k in ex)) continue
        o = ov[k] + 0
        ca = (cont[a ">" b] + 0) / (size[a] > 0 ? size[a] : 1)
        cb = (cont[b ">" a] + 0) / (size[b] > 0 ? size[b] : 1)
        if (ca > 1) ca = 1
        if (cb > 1) cb = 1
        mo = o
        if (mo > size[a]) mo = size[a]
        if (mo > size[b]) mo = size[b]
        den = size[a] + size[b] - mo
        jac = (den > 0 ? mo / den : 0)
        print a, b, o, jac, cnt[k] + 0, ca, cb, ex[k] + 0
    }
}
