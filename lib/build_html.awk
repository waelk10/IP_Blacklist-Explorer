# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# build_html.awk -- assemble the self-contained dashboard.
#
# All data is small (hundreds of rows).  SVG fragments and the stylesheet are
# inlined so dashboard.html has no external references and no JavaScript.

BEGIN {
    FS = "\t"

    while ((getline line < summary) > 0) {
        split(line, f, "\t"); S[f[1]] = f[2]
    }
    close(summary)

    while ((getline line < stats) > 0) {
        if (line == "") continue
        split(line, f, "\t")
        SLUG[f[2] + 0] = f[3]
        ADDR[f[2] + 0] = f[7] + 0
        RAW[f[2] + 0] = f[5] + 0
        RNG[f[2] + 0] = f[6] + 0
        DEG[f[2] + 0] = f[9] + 0
        SHR[f[2] + 0] = f[8] + 0
        ord[++sn] = f[2] + 0
    }
    close(stats)

    ec = 0
    while ((getline line < edges) > 0) {
        split(line, f, "\t")
        ec++
        ea[ec] = f[1] + 0; eb[ec] = f[2] + 0
        eov[ec] = f[3] + 0; ejac[ec] = f[4] + 0; eex[ec] = f[8] + 0
        eca[ec] = f[6] + 0; ecb[ec] = f[7] + 0
    }
    close(edges)

    while ((getline line < channels) > 0) {
        split(line, f, "\t")
        cc++
        ch[cc] = f[1]; ctot[cc] = f[2] + 0; cmat[cc] = f[3] + 0; cpct[cc] = f[4] + 0
    }
    close(channels)

    while ((getline line < service) > 0) {
        split(line, f, "\t")
        hh = f[3] + 0
        if (hh > besth[f[1]]) { besth[f[1]] = hh; besta[f[1]] = f[2] + 0 }
    }
    close(service)

    dc = 0
    while ((getline line < delta) > 0) {
        if (line == "") continue
        split(line, f, "\t")
        dc++
        dasn[dc] = f[1] + 0; dslug[dc] = f[2]; dst[dc] = f[3]
        dp[dc] = f[4] + 0; da[dc] = f[5] + 0
    }
    close(delta)

    ic = 0
    while ((getline line < insights) > 0) {
        split(line, f, "\t")
        ic++; ikind[ic] = f[1]; itext[ic] = f[2]
    }
    close(insights)

    bc = 0
    while ((getline line < blocks) > 0) {
        split(line, f, "\t")
        bc++; bsize[bc] = f[1] + 0; basn[bc] = f[2] + 0
        bslug[bc] = f[3]; bcidr[bc] = f[4]
    }
    close(blocks)

    mc = 0
    while ((getline line < empty) > 0) {
        split(line, f, "\t")
        mc++; masn[mc] = f[1]; mslug[mc] = f[2]; mraw[mc] = f[3] + 0
    }
    close(empty)

    gm = ""
    if ((getline line < gmeta) > 0) gm = line
    close(gmeta)
    split(gm, g, "\t")
    nsel = g[1] + 0; niso = g[2] + 0; nact = g[3] + 0; nrest = g[4] + 0
}

function h(s) {
    gsub(/&/, "\\&amp;", s)
    gsub(/</, "\\&lt;", s)
    gsub(/>/, "\\&gt;", s)
    gsub(/"/, "\\&quot;", s)
    return s
}

function commas(n,   s, r) {
    s = sprintf("%.0f", n)
    r = ""
    while (length(s) > 3) {
        r = "," substr(s, length(s) - 2) r
        s = substr(s, 1, length(s) - 3)
    }
    return s r
}

function human(x) {
    if (x >= 1e9) return sprintf("%.2fB", x / 1e9)
    if (x >= 1e6) return sprintf("%.1fM", x / 1e6)
    if (x >= 1e3) return sprintf("%.1fK", x / 1e3)
    return sprintf("%.0f", x)
}

function sigh(x) {
    if (x > 0) return "+" human(x)
    if (x < 0) return "-" human(-x)
    return "0"
}

function emit(path,   l) {
    while ((getline l < path) > 0) print l
    close(path)
}

function kv(k) { return (k in S ? S[k] : "") }

END {
    print "<!doctype html>"
    print "<html lang=\"en\">"
    print "<head>"
    print "<meta charset=\"utf-8\">"
    print "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    print "<title>ASNSCOPE - IP_Blacklist intelligence</title>"
    print "<style>"
    emit(css)
    print "</style>"
    print "</head>"
    print "<body>"
    print "<div class=\"wrap\">"

    # ---------------------------------------------------------------- hero
    print "<header class=\"hero\">"
    print "<div class=\"brand\">"
    print "<h1><span class=\"dot\"></span>ASNSCOPE</h1>"
    print "<p>Relations, address-space statistics and operator ownership in the <b>IP_Blacklist</b> repository. Static, local, no scripts.</p>"
    print "</div>"
    print "<div class=\"meta\">"
    printf "upstream <b>%s</b><br>\n", h(kv("upstream_timestamp"))
    printf "commit <b>%s</b> &middot; generated <b>%s</b><br>\n", h(kv("repo_commit")), h(kv("run_utc"))
    printf "<a href=\"https://github.com/waelk10/IP_Blacklist\" style=\"color:#5f7590\">%s</a>\n", h(kv("repo_url"))
    print "</div>"
    print "</header>"

    # ---------------------------------------------------------------- kpis
    print "<section class=\"kpis\">"
    printf "<div class=\"kpi\"><div class=\"k\">Active ASNs</div><div class=\"v\">%s</div><div class=\"s\">of %s tracked &middot; %s silent</div></div>\n", \
        kv("asns_active"), kv("asns_total"), kv("asns_empty")
    printf "<div class=\"kpi\"><div class=\"k\">Unique CIDRs</div><div class=\"v\">%s</div><div class=\"s\">%s listed rows</div></div>\n", \
        commas(kv("unique_cidrs")), commas(kv("prefixes"))
    printf "<div class=\"kpi\"><div class=\"k\">Tracked space</div><div class=\"v\">%s</div><div class=\"s\">%s in overlap (%s%%)</div></div>\n", \
        human(kv("union_addresses")), human(kv("overlap_addresses")), kv("overlap_pct")
    printf "<div class=\"kpi\"><div class=\"k\">Relations</div><div class=\"v\">%s</div><div class=\"s\">%s pairs share exact CIDRs</div></div>\n", \
        commas(kv("edges")), kv("shared_prefix_pairs")
    printf "<div class=\"kpi\"><div class=\"k\">Operator groups</div><div class=\"v\">%s</div><div class=\"s\">with more than one ASN</div></div>\n", \
        kv("owner_groups_multi")
    printf "<div class=\"kpi\"><div class=\"k\">Combined coverage</div><div class=\"v\">%s%%</div><div class=\"s\">%s of %s entries</div></div>\n", \
        kv("combined_pct"), human(kv("combined_matched")), human(kv("combined_total"))
    print "</section>"

    # --------------------------------------------------------------- graph
    print "<section class=\"panel\">"
    print "<h2>ASN relationship graph</h2>"
    printf "<p class=\"capt\">Nodes are ASNs, edges are shared listed address space. Node size ~ listed space; colour = operator group. The core view shows <b>%d</b> of %d active ASNs; %d lists are omitted, %d of them with no shared range at all. Hover a node or edge for numbers.</p>\n", nsel, nact, nrest, niso
    emit(svgdir "/graph.svg")
    emit(svgdir "/legend.html")
    print "<p class=\"note\">Edge weight is the summed intersection of merged ranges, not a BGP peering. Dashed edges join ASNs of the same operator.</p>"
    print "</section>"

    # ------------------------------------------------------ top / ownership
    print "<div class=\"grid two\">"
    print "<section class=\"panel\">"
    print "<h2>Largest ASNs by listed space</h2>"
    print "<p class=\"capt\">Union of each list's CIDRs after merging overlaps. Shares can sum past 100%.</p>"
    emit(svgdir "/top_asns.svg")
    print "</section>"
    print "<section class=\"panel\">"
    print "<h2>Operator groups</h2>"
    print "<p class=\"capt\">ASNs that share an operator slug in the upstream file name. This is list metadata, not a corporate registry.</p>"
    emit(svgdir "/owners.svg")
    print "</section>"
    print "</div>"

    # ------------------------------------------------------ matrix / prefix
    print "<div class=\"grid two\">"
    print "<section class=\"panel\">"
    print "<h2>Overlap matrix</h2>"
    print "<p class=\"capt\">Pairwise shared space between the fifteen largest ASNs, log colour scale. Hover a cell for exact values.</p>"
    emit(svgdir "/matrix.svg")
    print "</section>"
    print "<section class=\"panel\">"
    print "<h2>Prefix length distribution</h2>"
    print "<p class=\"capt\">How the lists are built: /24s dominate by count, while a handful of /8-/12 blocks dominate address space.</p>"
    emit(svgdir "/prefix_hist.svg")
    print "</section>"
    print "</div>"

    # ---------------------------------------------------------- relations
    print "<section class=\"panel\">"
    print "<h2>Strongest relations</h2>"
    print "<p class=\"capt\">Ranked by shared address space. \"same CIDRs\" counts prefixes listed under both ASNs; \"inside\" flags a list largely nested in the other.</p>"
    print "<table><thead><tr><th>ASN A</th><th>ASN B</th><th class=\"num\">shared</th><th class=\"num\">Jaccard</th><th class=\"num\">same CIDRs</th><th>nesting</th></tr></thead><tbody>"
    lim = (ec < 12 ? ec : 12)
    for (i = 1; i <= lim; i++) {
        nest = ""
        if (eca[i] > 0.85) nest = sprintf("AS%d mostly inside AS%d", ea[i], eb[i])
        else if (ecb[i] > 0.85) nest = sprintf("AS%d mostly inside AS%d", eb[i], ea[i])
        printf "<tr><td class=\"mono\">AS%d <span class=\"who\">%s</span></td><td class=\"mono\">AS%d <span class=\"who\">%s</span></td><td class=\"num\">%s</td><td class=\"num\">%.0f%%</td><td class=\"num\">%s</td><td class=\"who\">%s</td></tr>\n", \
            ea[i], h(SLUG[ea[i]]), eb[i], h(SLUG[eb[i]]), human(eov[i]), 100 * ejac[i], commas(eex[i]), nest
    }
    print "</tbody></table>"
    print "</section>"

    # ------------------------------------------------- channels / changes
    print "<div class=\"grid two\">"
    print "<section class=\"panel\">"
    print "<h2>Service channels</h2>"
    print "<p class=\"capt\">Addresses from per-service lists mapped to the most specific tracked ASN range.</p>"
    print "<table><thead><tr><th>channel</th><th class=\"num\">entries</th><th class=\"num\">matched</th><th class=\"num\">pct</th><th>top ASN</th></tr></thead><tbody>"
    for (i = 1; i <= cc; i++) {
        a = besta[ch[i]] + 0
        if (a == 0)
            printf "<tr><td class=\"mono\">%s</td><td class=\"num\">%s</td><td class=\"num\">%s</td><td class=\"num\">%.1f%%</td><td class=\"who\">-</td></tr>\n", \
                h(ch[i]), commas(ctot[i]), commas(cmat[i]), cpct[i]
        else
            printf "<tr><td class=\"mono\">%s</td><td class=\"num\">%s</td><td class=\"num\">%s</td><td class=\"num\">%.1f%%</td><td class=\"mono\">AS%d <span class=\"who\">%s</span> <span class=\"num\">(%d)</span></td></tr>\n", \
                h(ch[i]), commas(ctot[i]), commas(cmat[i]), cpct[i], a, h(SLUG[a]), besth[ch[i]]
    }
    print "</tbody></table>"
    print "</section>"

    print "<section class=\"panel\">"
    print "<h2>Changes since the previous run</h2>"
    if (dc == 0) {
        if (kv("has_previous") == "1")
            print "<p class=\"capt\">No list changed between the two snapshots.</p>"
        else
            print "<p class=\"capt\">First run: there is no previous snapshot to compare against. The next refresh will fill this table.</p>"
    } else {
        printf "<p class=\"capt\">Address-space delta for lists that moved. %d new, %d grown, %d shrunk, %d lost.</p>\n", \
            kv("delta_new"), kv("delta_grew"), kv("delta_shrank"), kv("delta_lost")
        print "<table><thead><tr><th>status</th><th>ASN</th><th class=\"num\">addresses</th><th class=\"num\">prefixes</th></tr></thead><tbody>"
        lim = (dc < 10 ? dc : 10)
        for (i = 1; i <= lim; i++) {
            cls = dst[i]
            printf "<tr><td><span class=\"tag %s\">%s</span></td><td class=\"mono\">AS%d <span class=\"who\">%s</span></td><td class=\"num\">%s</td><td class=\"num\">%+d</td></tr>\n", \
                cls, dst[i], dasn[i], h(dslug[i]), sigh(da[i]), dp[i]
        }
        print "</tbody></table>"
    }
    print "</section>"
    print "</div>"

    # --------------------------------------------------------- observations
    print "<section class=\"panel\">"
    print "<h2>Observations</h2>"
    print "<ul class=\"insights\">"
    for (i = 1; i <= ic; i++)
        printf "<li><span class=\"k\">%s</span><span class=\"t\">%s</span></li>\n", h(ikind[i]), h(itext[i])
    print "</ul>"
    print "</section>"

    # ------------------------------------------------------ blocks / silent
    print "<div class=\"grid two\">"
    print "<section class=\"panel\">"
    print "<h2>Largest single blocks</h2>"
    print "<p class=\"capt\">A single CIDR can carry more weight than thousands of /24s; useful when reading the address shares above.</p>"
    print "<table><thead><tr><th>CIDR</th><th class=\"num\">addresses</th><th>ASN</th></tr></thead><tbody>"
    lim = (bc < 8 ? bc : 8)
    for (i = 1; i <= lim; i++)
        printf "<tr><td class=\"mono\">%s</td><td class=\"num\">%s</td><td class=\"mono\">AS%d <span class=\"who\">%s</span></td></tr>\n", \
            h(bcidr[i]), human(bsize[i]), basn[i], h(bslug[i])
    print "</tbody></table>"
    print "</section>"

    print "<section class=\"panel\">"
    print "<h2>Tracked but silent</h2>"
    print "<p class=\"capt\">ASN files present upstream with no usable CIDR. They still count as tracked so the totals reconcile.</p>"
    print "<table><thead><tr><th>ASN</th><th>operator</th><th class=\"num\">rows</th></tr></thead><tbody>"
    for (i = 1; i <= mc; i++)
        printf "<tr><td class=\"mono\">AS%s</td><td>%s</td><td class=\"num\">%d</td></tr>\n", h(masn[i]), h(mslug[i]), mraw[i]
    print "</tbody></table>"
    print "</section>"
    print "</div>"

    # ------------------------------------------------------------- all rows
    print "<section class=\"panel\">"
    print "<h2>All tracked ASN lists</h2>"
    printf "<p class=\"capt\">Every row in the analysis, in ranking order. %d lists in total; the silent ones sit at the bottom with zero space.</p>\n", sn
    print "<details><summary>Show the full table</summary>"
    print "<table><thead><tr><th class=\"num\">#</th><th>ASN</th><th>operator</th><th class=\"num\">prefixes</th><th class=\"num\">ranges</th><th class=\"num\">space</th><th class=\"num\">share</th><th class=\"num\">relations</th></tr></thead><tbody>"
    for (q = 1; q <= sn; q++) {
        a = ord[q]
        printf "<tr><td class=\"num\">%d</td><td class=\"mono\">AS%d</td><td>%s</td><td class=\"num\">%s</td><td class=\"num\">%s</td><td class=\"num\">%s</td><td class=\"num\">%.2f%%</td><td class=\"num\">%d</td></tr>\n",             q, a, h(SLUG[a]), commas(RAW[a]), commas(RNG[a]), human(ADDR[a]), SHR[a], DEG[a]
    }
    print "</tbody></table></details>"
    print "</section>"

    # --------------------------------------------------------------- footer
    print "<footer>"
    print "<b>Method.</b> Each ASN file is parsed as IPv4 CIDRs, overlapping and adjacent ranges are merged, and address space is the size of the resulting union. Relations are intersections between merged ranges; Jaccard normalises by the two lists' sizes. Ownership groups come from the operator slug in the file name (<span class=\"mono\">AS&lt;number&gt;_&lt;slug&gt;</span>). Service lists are mapped by the most specific containing range. Nothing is enriched from WHOIS, BGP or a third party."
    print "<br><br>"
    print "<b>Limits.</b> A blacklist is not a map of the Internet: a /8 in a list is a claim, not a route announcement, and the same address can legitimately appear under several ASNs. Treat the numbers as a view of the list, not of abuse in the wild."
    print "<br><br>"
    printf "Generated by <b>asnscope %s</b> &middot; POSIX shell + awk + GNU Octave &middot; data from <a href=\"https://github.com/waelk10/IP_Blacklist\" style=\"color:#5f7590\">waelk10/IP_Blacklist</a>.\n", h(version)
    print "</footer>"
    print "</div>"
    print "</body>"
    print "</html>"
}
