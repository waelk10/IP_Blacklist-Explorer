# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# insights.awk -- a short, ranked list of observations for report + dashboard.
# All inputs are small TSVs produced by the analyze stage.

BEGIN {
    FS = OFS = "\t"
    while ((getline line < summary) > 0) {
        split(line, f, "\t"); S[f[1]] = f[2]
    }
    close(summary)

    n = 0
    while ((getline line < stats) > 0) {
        if (line == "") continue
        n++
        split(line, f, "\t")
        rank[n] = f[1] + 0
        asn[n] = f[2] + 0
        slug[n] = f[3]
        raw[n] = f[5] + 0
        addr[n] = f[7] + 0
        share[n] = f[8] + 0
        A[f[2] + 0] = n
        SLUG[f[2] + 0] = f[3]
    }
    close(stats)

    while ((getline line < edges) > 0) {
        split(line, f, "\t")
        ec++
        ea[ec] = f[1] + 0; eb[ec] = f[2] + 0
        eov[ec] = f[3] + 0; ejac[ec] = f[4] + 0
        eca[ec] = f[6] + 0; ecb[ec] = f[7] + 0; eex[ec] = f[8] + 0
    }
    close(edges)

    while ((getline line < owners) > 0) {
        split(line, f, "\t")
        oc++
        oname[oc] = f[1]; on[oc] = f[2] + 0
        oaddr[oc] = f[3] + 0; oshare[oc] = f[4] + 0; olist[oc] = f[6]
    }
    close(owners)

    while ((getline line < channels) > 0) {
        split(line, f, "\t")
        cc++
        ch[cc] = f[1]; ctot[cc] = f[2] + 0; cmat[cc] = f[3] + 0; cpct[cc] = f[4] + 0
    }
    close(channels)

    while ((getline line < service) > 0) {
        split(line, f, "\t")
        sha[f[2] + 0] += f[3] + 0
        if (f[3] + 0 > best_ch_hits) { best_ch_hits = f[3] + 0; best_ch_asn = f[2] + 0; best_ch_name = f[1] }
    }
    close(service)

    while ((getline line < bigprefix) > 0) {
        split(line, f, "\t")
        bp++; bpsize[bp] = f[1] + 0; bpasn[bp] = f[2] + 0; bpcidr[bp] = f[4]
    }
    close(bigprefix)
}

function human(x,   u, s) {
    if (x >= 1000000000) { u = "B"; s = x / 1000000000 }
    else if (x >= 1000000) { u = "M"; s = x / 1000000 }
    else if (x >= 1000) { u = "K"; s = x / 1000 }
    else return sprintf("%.0f", x)
    return sprintf("%.1f%s", s, u)
}

END {
    # 1. concentration
    top = 0
    for (i = 1; i <= n && i <= 10; i++) top += share[i]
    if (n > 0)
        print "concentration", sprintf("The ten largest ASNs account for %.1f%% of the tracked address space (top: AS%d %s, %.1f%%).", top, asn[1], slug[1], share[1])

    # 2. most fragmented (many prefixes, little space)
    frag = -1
    for (i = 1; i <= n; i++) {
        if (raw[i] < 50 || addr[i] <= 0) continue
        avg = addr[i] / raw[i]
        if (frag < 0 || avg < frag) { frag = avg; fi = i }
    }
    if (frag >= 0)
        print "fragmentation", sprintf("AS%d %s is the most fragmented list: %d prefixes averaging only %.0f addresses each.", asn[fi], slug[fi], raw[fi], frag)

    # 3. strongest relation
    if (ec > 0) {
        line = sprintf("AS%d %s and AS%d %s share %s addresses (Jaccard %.0f%%", ea[1], SLUG[ea[1]], eb[1], SLUG[eb[1]], human(eov[1]), 100 * ejac[1])
        if (eex[1] > 0) line = line sprintf(", %d identical CIDRs", eex[1])
        print "relation", line ")."
    }

    # 4. nesting / inferred upstream
    best = 0
    for (i = 1; i <= ec; i++) {
        if (eca[i] > best) { best = eca[i]; bi = i; dir = 1 }
        if (ecb[i] > best) { best = ecb[i]; bi = i; dir = 2 }
    }
    if (best > 0.85) {
        if (dir == 1)
            print "nesting", sprintf("%.0f%% of AS%d %s's listed space sits inside AS%d %s (possible upstream or leased ranges).", 100 * best, ea[bi], SLUG[ea[bi]], eb[bi], SLUG[eb[bi]])
        else
            print "nesting", sprintf("%.0f%% of AS%d %s's listed space sits inside AS%d %s (possible upstream or leased ranges).", 100 * best, eb[bi], SLUG[eb[bi]], ea[bi], SLUG[ea[bi]])
    }

    # 5. largest single CIDR
    if (bp > 0)
        print "block", sprintf("The largest single listed block is %s (%s addresses) under AS%d %s.", bpcidr[1], human(bpsize[1]), bpasn[1], SLUG[bpasn[1]])

    # 6. owner group
    obest = 0
    for (i = 1; i <= oc; i++) if (on[i] > 1 && oaddr[i] > obest) { obest = oaddr[i]; oi = i }
    if (obest > 0)
        print "ownership", sprintf("%s operates %d ASNs (%s) with %s addresses combined.", oname[oi], on[oi], olist[oi], human(oaddr[oi]))

    # 7. channel fingerprint
    bsa = 0
    for (a in sha) if (sha[a] > bsa) { bsa = sha[a]; bsa_asn = a }
    if (bsa > 0)
        print "channels", sprintf("AS%d %s is the most persistent across service lists (%d hits; biggest single channel: %s, %d hits).", bsa_asn, SLUG[bsa_asn], bsa, best_ch_name, best_ch_hits)

    # 8. data hygiene
    empty = S["asns_empty"] + 0
    if (empty > 0)
        print "quality", sprintf("%d ASN files are present but empty; they are kept as tracked-but-silent rather than dropped.", empty)
    if (S["combined_pct"] != "")
        print "coverage", sprintf("%s%% of combined_list is covered by a tracked ASN (%s of %s entries); the rest is unattributed blacklist space.", S["combined_pct"], human(S["combined_matched"] + 0), human(S["combined_total"] + 0))

    # 9. change
    dn = S["delta_new"] + 0; dg = S["delta_grew"] + 0
    ds = S["delta_shrank"] + 0; dl = S["delta_lost"] + 0
    if (dn + dg + ds + dl > 0)
        print "change", sprintf("Since the previous snapshot: %d new, %d grown, %d shrunk, %d lost ASN list(s).", dn, dg, ds, dl)
}
