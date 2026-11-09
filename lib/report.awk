# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# report.awk -- plain-text briefing for terminals, mail and diffing.
# Invoked with -v paths for the small tables produced by analyze.

BEGIN {
    FS = "\t"
    while ((getline line < summary) > 0) {
        split(line, f, "\t"); S[f[1]] = f[2]
    }
    close(summary)

    n = 0
    while ((getline line < stats) > 0) {
        if (line == "") continue
        n++
        split(line, f, "\t")
        rank[n] = f[1] + 0; asn[n] = f[2] + 0; slug[n] = f[3]
        raw[n] = f[5] + 0; addr[n] = f[7] + 0; share[n] = f[8] + 0
        deg[n] = f[9] + 0
        A[f[2] + 0] = n
    }
    close(stats)

    ec = 0
    while ((getline line < edges) > 0) {
        split(line, f, "\t")
        ec++
        ea[ec] = f[1] + 0; eb[ec] = f[2] + 0
        eov[ec] = f[3] + 0; ejac[ec] = f[4] + 0; eex[ec] = f[8] + 0
    }
    close(edges)

    oc = 0
    while ((getline line < owners) > 0) {
        split(line, f, "\t")
        oc++
        oname[oc] = f[1]; on[oc] = f[2] + 0
        oaddr[oc] = f[3] + 0; oshare[oc] = f[4] + 0; olist[oc] = f[6]
    }
    close(owners)

    cc = 0
    while ((getline line < channels) > 0) {
        split(line, f, "\t")
        cc++
        ch[cc] = f[1]; ctot[cc] = f[2] + 0; cmat[cc] = f[3] + 0; cpct[cc] = f[4] + 0
    }
    close(channels)

    while ((getline line < service) > 0) {
        split(line, f, "\t")
        h = f[3] + 0
        if (h > best_h[f[1]]) { best_h[f[1]] = h; best_a[f[1]] = f[2] + 0 }
    }
    close(service)

    dc = 0
    while ((getline line < delta) > 0) {
        if (line == "") continue
        split(line, f, "\t")
        dc++
        dasn[dc] = f[1] + 0; dslug[dc] = f[2]; dst[dc] = f[3]
        dp[dc] = f[4] + 0; da[dc] = f[5] + 0; ds[dc] = f[6] + 0
    }
    close(delta)

    ic = 0
    while ((getline line < insights) > 0) {
        split(line, f, "\t")
        ic++; ikind[ic] = f[1]; itext[ic] = f[2]
    }
    close(insights)
}

function human(x,   u, s) {
    if (x >= 1000000000) { u = "B"; s = x / 1000000000 }
    else if (x >= 1000000) { u = "M"; s = x / 1000000 }
    else if (x >= 1000) { u = "K"; s = x / 1000 }
    else return sprintf("%.0f", x)
    return sprintf("%.1f%s", s, u)
}

function hdelta(x) {
    if (x > 0) return "+" human(x)
    if (x < 0) return "-" human(-x)
    return "0"
}

function trim(s, n) { return (length(s) > n ? substr(s, 1, n - 1) "." : s) }

function rule(c, n,   i, s) {
    s = ""
    for (i = 0; i < n; i++) s = s c
    return s
}

END {
    printf "%s\n", rule("=", 78)
    print " ASNSCOPE - IP_Blacklist intelligence briefing"
    printf "%s\n", rule("=", 78)
    printf " run       %s\n", S["run_utc"]
    printf " upstream  %s\n", S["upstream_timestamp"]
    printf " repo      %s (%s)\n", S["repo_commit"], S["repo_commit_date"]
    printf " lists     %s ASNs: %s with data, %s empty\n", S["asns_total"], S["asns_active"], S["asns_empty"]
    printf " prefixes  %s unique CIDRs (%s listed rows, %s merged ranges)\n", S["unique_cidrs"], S["prefixes"], S["ranges"]
    printf " space     %s addresses in %s ranges\n", human(S["union_addresses"] + 0), S["union_ranges"]
    printf " overlap   %s (%s%%) claimed by 2+ ASNs, max depth %s\n", human(S["overlap_addresses"] + 0), S["overlap_pct"], S["max_depth"]
    printf " relations %s pairs, %s with identical CIDRs\n", S["edges"], S["shared_prefix_pairs"]
    printf " owners    %s operator group(s) with more than one ASN\n", S["owner_groups_multi"]
    printf " combined  %s%% attributed (%s of %s entries)\n", S["combined_pct"], S["combined_matched"], S["combined_total"]

    printf "\n%s\n TOP ASNs BY LISTED ADDRESS SPACE\n%s\n", rule("-", 78), rule("-", 78)
    printf " %3s %7s %9s %8s  %-9s %s\n", "#", "share", "space", "prefixes", "ASN", "operator"
    lim = (n < 15 ? n : 15)
    for (i = 1; i <= lim; i++)
        printf " %3d %6.2f%% %9s %8d  AS%-7d %s\n", rank[i], share[i], human(addr[i]), raw[i], asn[i], trim(slug[i], 30)

    printf "\n%s\n STRONGEST ASN RELATIONS (shared address space)\n%s\n", rule("-", 78), rule("-", 78)
    printf " %-9s %-9s %9s %7s %8s\n", "ASN A", "ASN B", "overlap", "jaccard", "sameCIDR"
    lim = (ec < 12 ? ec : 12)
    for (i = 1; i <= lim; i++)
        printf " AS%-7d AS%-7d %9s %6.0f%% %8d   %s <-> %s\n", \
            ea[i], eb[i], human(eov[i]), 100 * ejac[i], eex[i], trim(slug[A[ea[i]]], 16), trim(slug[A[eb[i]]], 16)

    printf "\n%s\n OPERATOR GROUPS WITH MULTIPLE ASNs\n%s\n", rule("-", 78), rule("-", 78)
    shown = 0
    for (i = 1; i <= oc && shown < 10; i++) {
        if (on[i] < 2) continue
        shown++
        printf " %-14s %d ASN(s)  %9s  %5.2f%%  %s\n", trim(oname[i], 14), on[i], human(oaddr[i]), oshare[i], trim(olist[i], 46)
    }
    if (shown == 0) print " (none this run)"

    printf "\n%s\n SERVICE CHANNELS (addresses matched to a tracked ASN)\n%s\n", rule("-", 78), rule("-", 78)
    printf " %-18s %8s %8s %6s  %s\n", "channel", "entries", "matched", "pct", "top ASN"
    for (i = 1; i <= cc; i++) {
        a = best_a[ch[i]] + 0
        if (a == 0)
            printf " %-18s %8d %8d %5.1f%%  -\n", ch[i], ctot[i], cmat[i], cpct[i]
        else
            printf " %-18s %8d %8d %5.1f%%  AS%-7d %s (%d)\n", ch[i], ctot[i], cmat[i], cpct[i], a, trim(slug[A[a]], 20), best_h[ch[i]]
    }

    printf "\n%s\n CHANGES SINCE THE PREVIOUS RUN\n%s\n", rule("-", 78), rule("-", 78)
    if (dc == 0) {
        if (S["has_previous"] == "1") print " no changes since the previous snapshot"
        else print " first run: no previous snapshot to compare against"
    } else {
        printf " %-8s %-7s %10s %9s  %s\n", "status", "ASN", "addresses", "prefixes", "operator"
        lim = (dc < 12 ? dc : 12)
        for (i = 1; i <= lim; i++)
            printf " %-8s AS%-5d %10s %+9d  %s\n", dst[i], dasn[i], hdelta(da[i]), dp[i], trim(dslug[i], 30)
    }

    printf "\n%s\n OBSERVATIONS\n%s\n", rule("-", 78), rule("-", 78)
    for (i = 1; i <= ic; i++) printf " [%-13s] %s\n", ikind[i], itext[i]

    printf "\n%s\n", rule("-", 78)
    print " Space is the union of each ASN's CIDRs after merging. Shares overlap, so"
    print " they can sum past 100%. Relations are inferred from shared ranges, not"
    print " from BGP data; ownership groups come from the operator slug in the file"
    print " name. Treat all of it as a map of the list, not a map of the Internet."
    printf "%s\n", rule("=", 78)
}
