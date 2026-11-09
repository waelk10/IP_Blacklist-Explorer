# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# extract.awk -- turn "AS<num>_<slug>" banlist files into one flat CIDR table.
#
# Input : ip_banlists/AS* files, one IPv4 address or CIDR per line.
# Output: TSV  asn  slug  cidr  first  last  prefixlen
#
# Only IPv4 is handled (the upstream lists contain no IPv6).  Malformed
# records are skipped silently; they are counted in the summary by the
# caller if it cares.

BEGIN { OFS = "\t" }

{
    line = $0
    sub(/\r$/, "", line)
    gsub(/^[ \t]+/, "", line)
    gsub(/[ \t]+$/, "", line)
    if (line == "" || line ~ /^#/) next

    n = split(FILENAME, path, "/")
    base = path[n]
    if (base !~ /^AS[0-9]+_/) next

    u = index(base, "_")
    asn = substr(base, 3, u - 3)
    slug = substr(base, u + 1)
    if (asn == "" || slug == "") next

    # --- parse address[/prefix] -------------------------------------
    np = split(line, p, "/")
    if (np > 2) next
    no = split(p[1], o, ".")
    if (no != 4) next

    ok = 1
    for (i = 1; i <= 4; i++) {
        if (o[i] !~ /^[0-9]+$/ || (o[i] + 0) > 255) ok = 0
    }
    if (!ok) next

    plen = 32
    if (np == 2) {
        if (p[2] !~ /^[0-9]+$/) next
        plen = p[2] + 0
        if (plen < 0 || plen > 32) next
    }

    first = ((o[1] * 256 + o[2]) * 256 + o[3]) * 256 + o[4]
    if (plen < 32) {
        block = 2 ^ (32 - plen)
        first = int(first / block) * block
        last = first + block - 1
    } else {
        last = first
    }

    print asn, slug, p[1] (np == 2 ? "/" p[2] : ""), first, last, plen
}
