# Copyright (C) 2026 Wael Karram
# SPDX-License-Identifier: AGPL-3.0-or-later

# depth.awk -- how much address space is claimed by two or more ASNs.
# Input: events "position delta" sorted by position, delta ascending
#        (-1 before +1 at the same position).
# Output: one line "overlap_addresses max_depth".

BEGIN { prev = -1; depth = 0; area = 0; maxd = 0 }

{
    p = $1 + 0
    if (p != prev) {
        if (prev >= 0 && depth >= 2) area += p - prev
        prev = p
    }
    depth += $2
    if (depth > maxd) maxd = depth
}

END { print area, maxd }
