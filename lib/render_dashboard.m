% Copyright (C) 2026 Wael Karram
% SPDX-License-Identifier: AGPL-3.0-or-later

function render_dashboard(outdir, sharedir)
% RENDER_DASHBOARD  Draw the static SVG panels for asnscope.
%
%   render_dashboard(OUTDIR, SHAREDIR)
%
% Reads the TSV tables written by the analyze stage and writes SVG fragments
% to OUTDIR/parts/.  No plotting toolkit, display or font server is used:
% the panels are plain SVG, which keeps the result identical on headless
% machines and makes the dashboard a single self-contained HTML file.
%
% Everything here is deterministic, so two runs over the same data produce
% byte-identical drawings (apart from the data itself).

    parts = fullfile(outdir, 'parts');
    if ~exist(parts, 'dir'); mkdir(parts); end

    ST = read_tsv(fullfile(outdir, 'asn_stats.tsv'), 11);
    E  = read_tsv(fullfile(outdir, 'edges.tsv'), 8);
    OW = read_tsv(fullfile(outdir, 'owners.tsv'), 6);
    PH = read_tsv(fullfile(outdir, 'prefix_hist.tsv'), 3);

    asn   = str2double(ST(:,2));
    slug  = ST(:,3);
    raw   = str2double(ST(:,5));
    addr  = str2double(ST(:,7));
    share = str2double(ST(:,8));
    deg   = str2double(ST(:,9));

    active = find(addr > 0);
    n = numel(active);
    a_asn = asn(active); a_slug = slug(active);
    a_addr = addr(active); a_share = share(active);
    a_raw = raw(active); a_deg = deg(active);

    [nodecol, gnames, gcounts, gaddr, gmembers, gid] = assign_colours(a_asn, a_slug, a_addr);
    % edges, restricted to ASNs that actually have data
    ea = str2double(E(:,1)); eb = str2double(E(:,2));
    eov = str2double(E(:,3)); ejac = str2double(E(:,4));
    eex = str2double(E(:,8));
    [okA, locA] = ismember(ea, a_asn);
    [okB, locB] = ismember(eb, a_asn);
    keep = okA & okB;
    ei = locA(keep); ej = locB(keep);
    ew = eov(keep); ejac2 = ejac(keep); eex2 = eex(keep);
    m = numel(ei);
    ei = ei(1:m); ej = ej(1:m); ew = ew(1:m);
    ejac2 = ejac2(1:m); eex2 = eex2(1:m);

    % A 198-node hairball is not a visualisation.  The core graph keeps the
    % largest ASNs, the most connected ones and every member of a multi-ASN
    % operator group.  The complete relation table stays in edges.tsv.
    edeg = zeros(n, 1);
    for k = 1:m; edeg(ei(k)) = edeg(ei(k)) + 1; edeg(ej(k)) = edeg(ej(k)) + 1; end
    [~, byaddr] = sort(a_addr, 'descend');
    [~, bydeg] = sort(edeg, 'descend');
    biggroups = find(gaddr > 2e5);
    sel = unique([byaddr(1:min(30, n)); bydeg(1:min(10, n)); ...
                  find(ismember(gid, biggroups) & gid > 0)]);
    remap = zeros(n, 1);
    remap(sel) = 1:numel(sel);
    keep2 = ismember(ei, sel) & ismember(ej, sel);
    ci = remap(ei(keep2)); cj = remap(ej(keep2)); cw = ew(keep2);
    fid = fopen(fullfile(parts, 'graph_meta.tsv'), 'w');
    fprintf(fid, '%d\t%d\t%d\t%d\n', numel(sel), sum(edeg == 0), n, n - numel(sel));
    fclose(fid);
    draw_graph(parts, a_asn(sel), a_slug(sel), a_addr(sel), a_share(sel), ...
               a_raw(sel), a_deg(sel), ci, cj, cw, nodecol(sel), ...
               gid(sel), gnames, gcounts, n - numel(sel));
    draw_top_asns(parts, a_asn, a_slug, a_addr, a_share, a_raw, nodecol, active);
    draw_owners(parts, gnames, gcounts, gaddr, gmembers, a_asn, a_addr, a_slug);
    draw_matrix(parts, a_asn, a_slug, ei, ej, ew, ejac2);
    draw_prefix_hist(parts, PH);
    gcntg = zeros(numel(gnames), 1);
    for i = 1:numel(sel)
        if gid(sel(i)) > 0; gcntg(gid(sel(i))) = gcntg(gid(sel(i))) + 1; end
    end
    write_legend(parts, gnames, gcntg, sum(gid(sel) == 0));
end

% ---------------------------------------------------------------------------
% input helpers
% ---------------------------------------------------------------------------

function C = read_tsv(path, ncols)
    C = cell(0, ncols);
    if ~exist(path, 'file'); return; end
    fid = fopen(path, 'r');
    if fid < 0; return; end
    while true
        line = fgetl(fid);
        if ~ischar(line); break; end
        if isempty(line); continue; end
        p = strsplit(line, sprintf('\t'), 'CollapseDelimiters', false);
        if numel(p) < ncols
            p(end+1:ncols) = {''};
        end
        C(end+1,:) = p(1:ncols);
    end
    fclose(fid);
end

% ---------------------------------------------------------------------------
% small formatting helpers
% ---------------------------------------------------------------------------

function s = human(x)
    if x >= 1e9
        s = sprintf('%.2fB', x / 1e9);
    elseif x >= 1e6
        s = sprintf('%.1fM', x / 1e6);
    elseif x >= 1e3
        s = sprintf('%.1fK', x / 1e3);
    elseif x >= 1
        s = sprintf('%.0f', x);
    else
        s = sprintf('%.2f', x);
    end
    s = strrep(s, '.0K', 'K');
    s = strrep(s, '.0M', 'M');
    s = strrep(s, '.0B', 'B');
end

function s = esc(t)
    s = strrep(t, '&', '&amp;');
    s = strrep(s, '<', '&lt;');
    s = strrep(s, '>', '&gt;');
    s = strrep(s, '"', '&quot;');
end

function w(fid, s)
    fprintf(fid, '%s\n', s);
end

function s = mix(c1, c2, t)
    if t < 0; t = 0; elseif t > 1; t = 1; end
    a = hex2dec(c1(2:3)); b = hex2dec(c1(4:5)); c = hex2dec(c1(6:7));
    d = hex2dec(c2(2:3)); e = hex2dec(c2(4:5)); f = hex2dec(c2(6:7));
    r = round(a + (d - a) * t);
    g = round(b + (e - b) * t);
    bl = round(c + (f - c) * t);
    s = sprintf('#%02x%02x%02x', r, g, bl);
end

function txt(fid, x, y, s, size, fill, anchor, weight)
    if nargin < 8; weight = 'normal'; end
    if nargin < 7; anchor = 'start'; end
    fprintf(fid, ['<text x="%.1f" y="%.1f" font-size="%d" fill="%s" ' ...
                  'text-anchor="%s" font-weight="%s">%s</text>\n'], ...
            x, y, size, fill, anchor, weight, esc(s));
end

function pal = owner_palette()
    pal = {'#4fb8ff', '#ff8a5c', '#52d6a3', '#f2c14e', ...
           '#b28dff', '#ff7ab6', '#3ddbd9', '#a3e635'};
end

% ---------------------------------------------------------------------------
% ownership colours
% ---------------------------------------------------------------------------

function [nodecol, gnames, gcounts, gaddr, gmembers, gid] = assign_colours(asn, slug, addr)
    pal = owner_palette();
    n = numel(slug);
    nodecol = repmat({'#64748b'}, n, 1);
    gid = zeros(n, 1);

    key = lower(slug);
    [u, ~, ic] = unique(key);
    cnt = accumarray(ic, 1);
    tot = accumarray(ic, addr);
    multi = find(cnt > 1);
    [~, ord] = sort(tot(multi), 'descend');
    multi = multi(ord);

    gnames = {}; gcounts = []; gaddr = []; gmembers = {};
    for q = 1:numel(multi)
        gi = multi(q);
        c = pal{mod(q - 1, numel(pal)) + 1};
        gnames{q,1} = u{gi};
        gcounts(q,1) = cnt(gi);
        gaddr(q,1) = tot(gi);
        gmembers{q,1} = {};
        for i = find(ic == gi)'
            nodecol{i} = c;
            gid(i) = q;
            gmembers{q,1}{end+1} = sprintf('AS%d %s (%s)', ...
                asn(i), slug{i}, human(addr(i)));
        end
    end
end

% ---------------------------------------------------------------------------
% force-directed graph
% ---------------------------------------------------------------------------

function draw_graph(parts, asn, slug, addr, share, raw, deg, ei, ej, ew, nodecol, gid, gnames, gcounts, nisolated)
    W = 1160; H = 680;
    n = numel(asn);
    m = numel(ei);

    maxov = max([ew; 1]);
    wt = 0.25 + 0.85 * sqrt(ew / maxov);

    % invisible affinity springs keep ASNs of one operator together
    affi = []; affj = []; affw = [];
    for i = 1:n
        if gid(i) == 0; continue; end
        for j = i+1:n
            if gid(j) == gid(i)
                affi(end+1,1) = i; affj(end+1,1) = j; affw(end+1,1) = 0.6;
            end
        end
    end
    [X, Y] = force_layout(n, [ei; affi], [ej; affj], [wt; affw], W, H);

    fid = fopen(fullfile(parts, 'graph.svg'), 'w');
    svg_head(fid, W, H, 'ASN relationship graph');
    w(fid, '<rect x="0" y="0" width="1160" height="680" fill="#0d1526"/>');

    % edges, weak first so strong relations sit on top
    [~, ord] = sort(ew, 'ascend');
    for q = 1:m
        k = ord(q);
        a = ei(k); b = ej(k);
        t = sqrt(ew(k) / maxov);
        same = strcmp(nodecol{a}, nodecol{b}) && ~strcmp(nodecol{a}, '#64748b');
        if same
            stroke = nodecol{a}; op = 0.30 + 0.45 * t; dash = ' stroke-dasharray="4 4"';
        else
            stroke = '#ff7a6b'; op = 0.16 + 0.50 * t; dash = '';
        end
        fprintf(fid, ['<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" ' ...
                      'stroke="%s" stroke-opacity="%.2f" stroke-width="%.2f"%s>' ...
                      '<title>AS%d %s - AS%d %s: %s shared addresses</title></line>\n'], ...
                X(a), Y(a), X(b), Y(b), stroke, op, 0.8 + 2.4 * t, dash, ...
                asn(a), esc(slug{a}), asn(b), esc(slug{b}), human(ew(k)));
    end

    % nodes
    r = 3.5 + 4.3 * log10(1 + addr / 1e4);
    r = min(r, 17);
    [~, bysize] = sort(addr, 'descend');
    for q = 1:n
        i = bysize(q);
        fprintf(fid, ['<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" ' ...
                      'stroke="#0d1526" stroke-width="1.6" fill-opacity="0.92">' ...
                      '<title>AS%d %s\n%s addresses (%.2f%% of tracked space)\n' ...
                      '%d listed prefixes, %d relations</title></circle>\n'], ...
                X(i), Y(i), r(i), nodecol{i}, asn(i), esc(slug{i}), ...
                human(addr(i)), share(i), raw(i), deg(i));
    end

    % labels for the biggest nodes, with a simple collision test
    placed = zeros(0, 4);
    for q = 1:n
        i = bysize(q);
        label = sprintf('AS%d %s', asn(i), slug{i});
        if length(label) > 26; label = [label(1:23) '...']; end
        lw = 6.4 * length(label) + 4;
        lh = 13;
        placed_here = false;
        for side = [1 -1]
            for dy = [-5 10 -18 23]
                if side == 1
                    x0 = X(i) + r(i) + 5; anchor = 'start';
                else
                    x0 = X(i) - r(i) - 5 - lw; anchor = 'end';
                end
                y0 = Y(i) + dy;
                if x0 < 4 || x0 + lw > W - 4; continue; end
                hit = false;
                for p = 1:size(placed, 1)
                    if ~(x0 + lw + 2 < placed(p,1) || x0 > placed(p,1) + placed(p,3) + 2 || ...
                         y0 + lh + 2 < placed(p,2) || y0 > placed(p,2) + placed(p,4) + 2)
                        hit = true; break;
                    end
                end
                if ~hit
                    fprintf(fid, ['<text x="%.1f" y="%.1f" font-size="10.5" fill="#dbe7f7" ' ...
                                  'text-anchor="%s" font-weight="600" stroke="#0d1526" ' ...
                                  'stroke-width="3" paint-order="stroke">%s</text>\n'], ...
                            x0, y0 + 9, anchor, esc(label));
                    placed(end+1,:) = [x0, y0, lw, lh];
                    placed_here = true;
                    break;
                end
            end
            if placed_here; break; end
        end
    end
    w(fid, '</g></svg>');
    fclose(fid);
end

function [X, Y] = force_layout(n, ei, ej, ew, W, H)
    % deterministic phyllotaxis start
    ang = 2 * pi * (0:n-1)' / max(n, 1) + 0.4;
    rad = 0.30 + 0.10 * mod((1:n)', 3) / 2;
    X = W/2 + rad .* cos(ang) * W * 0.40;
    Y = H/2 + rad .* sin(ang) * H * 0.38;

    area = (0.82 * W) * (0.78 * H);
    k = sqrt(area / n);
    iters = 760;
    t0 = 26;

    for it = 1:iters
        dx = X - X';
        dy = Y - Y';
        d2 = dx.^2 + dy.^2;
        d2(1:n+1:end) = 1;
        d = sqrt(d2);
        F = (k * k) ./ d;
        F(d > 2.9 * k) = 0;
        F = F + 1500 ./ (d .* d);
        F(d > 2.9 * k) = 0;
        ux = dx ./ d;
        uy = dy ./ d;
        fx = sum(F .* ux, 2);
        fy = sum(F .* uy, 2);

        for e = 1:numel(ei)
            i = ei(e); j = ej(e);
            ddx = X(i) - X(j);
            ddy = Y(i) - Y(j);
            dd = sqrt(ddx^2 + ddy^2) + 1e-9;
            f = 0.30 * (dd * dd) / k * ew(e);
            uxx = ddx / dd; uyy = ddy / dd;
            fx(i) = fx(i) - f * uxx; fy(i) = fy(i) - f * uyy;
            fx(j) = fx(j) + f * uxx; fy(j) = fy(j) + f * uyy;
        end

        fx = fx + 0.15 * (W/2 - X);
        fy = fy + 0.15 * (H/2 - Y);

        temp = t0 * (1 - it / iters) + 0.4;
        mag = sqrt(fx.^2 + fy.^2) + 1e-12;
        step = min(mag, temp) ./ mag;
        X = X + fx .* step;
        Y = Y + fy .* step;
    end

    padx = 90; pady = 70;
    X = normalise(X, padx, W - padx);
    Y = normalise(Y, pady, H - pady);
end

function v = normalise(v, lo, hi)
    a = min(v); b = max(v);
    if b - a < 1e-9
        v = (lo + hi) / 2 * ones(size(v));
    else
        v = (v - a) / (b - a) * (hi - lo) + lo;
    end
end

function svg_head(fid, W, H, title)
    fprintf(fid, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" width="100%%" role="img" aria-label="%s">\n', W, H, esc(title));
    fprintf(fid, '<title>%s</title>\n', esc(title));
    fprintf(fid, '<g font-family="-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica, Arial, sans-serif">\n');
end

% ---------------------------------------------------------------------------
% top ASNs
% ---------------------------------------------------------------------------

function draw_top_asns(parts, asn, slug, addr, share, raw, nodecol, active)
    W = 600; H = 560;
    left = 232; right = 505; top = 34; row = 34;
    maxshare = max(share) * 1.06;
    fid = fopen(fullfile(parts, 'top_asns.svg'), 'w');
    svg_head(fid, W, H, 'Largest ASNs by listed address space');
    w(fid, '<rect x="0" y="0" width="600" height="560" fill="#0d1526"/>');
    w(fid, sprintf('<line x1="%d" y1="%d" x2="%d" y2="%d" stroke="#223049" stroke-width="1"/>\n', ...
        left, top - 12, left, top + 15 * row + 2));

    for q = 1:min(15, numel(asn))
        i = q;
        y = top + (q - 1) * row;
        bw = (right - left) * share(i) / maxshare;
        name = slug{i};
        if length(name) > 22; name = [name(1:20) '..']; end
        txt(fid, 14, y + 15, sprintf('%2d', q), 10.5, '#5f7590', 'start', 'normal');
        txt(fid, 40, y + 15, sprintf('AS%d', asn(i)), 11, '#8fa3bd', 'start', '600');
        txt(fid, 104, y + 15, name, 11.5, '#e6edf7', 'start', 'normal');
        fprintf(fid, '<rect x="%d" y="%d" width="%.1f" height="17" rx="3" fill="%s" fill-opacity="0.88"><title>AS%d %s: %s addresses (%.2f%%), %d prefixes</title></rect>\n', ...
            left, y + 3, bw, nodecol{i}, asn(i), esc(slug{i}), human(addr(i)), share(i), raw(i));
        val = sprintf('%s  %.1f%%', human(addr(i)), share(i));
        txt(fid, left + bw + 7, y + 15, val, 10.5, '#93a4bd', 'start', 'normal');
    end
    w(fid, '</g></svg>');
    fclose(fid);
end

% ---------------------------------------------------------------------------
% owner groups
% ---------------------------------------------------------------------------

function draw_owners(parts, gnames, gcounts, gaddr, gmembers, asn, addr, slug)
    W = 600; H = 430;
    fid = fopen(fullfile(parts, 'owners.svg'), 'w');
    svg_head(fid, W, H, 'Operator groups with more than one ASN');
    w(fid, '<rect x="0" y="0" width="600" height="430" fill="#0d1526"/>');

    pal = owner_palette();
    ng = numel(gnames);
    if ng == 0
        txt(fid, W/2, H/2, 'No multi-ASN operator groups this run.', 13, '#93a4bd', 'middle', 'normal');
        w(fid, '</g></svg>'); fclose(fid); return;
    end

    left = 176; right = 548; top = 34; row = 44;
    maxa = max(gaddr);
    for q = 1:ng
        y = top + (q - 1) * row;
        bw = (right - left) * sqrt(gaddr(q) / maxa);
        name = gnames{q};
        if length(name) > 20; name = [name(1:18) '..']; end
        txt(fid, 14, y + 16, name, 11.5, '#e6edf7', 'start', '600');
        txt(fid, 14, y + 29, sprintf('%d ASNs', gcounts(q)), 9.5, '#6f849f', 'start', 'normal');
        c = pal{mod(q - 1, numel(pal)) + 1};
        fprintf(fid, '<rect x="%d" y="%d" width="%.1f" height="20" rx="3" fill="%s" fill-opacity="0.85"><title>%s: %s addresses across %d ASNs</title></rect>\n', ...
            left, y + 4, bw, c, esc(name), human(gaddr(q)), gcounts(q));
        txt(fid, left + bw + 7, y + 18, human(gaddr(q)), 10.5, '#93a4bd', 'start', 'normal');
    end

    txt(fid, 14, H - 12, 'bar length ~ sqrt(listed space); groups are inferred from the operator slug in the file name', 9.5, '#5f7590', 'start', 'normal');
    w(fid, '</g></svg>');
    fclose(fid);
end

% ---------------------------------------------------------------------------
% overlap matrix
% ---------------------------------------------------------------------------

function draw_matrix(parts, asn, slug, ei, ej, ew, jac)
    W = 620; H = 640;
    k = min(15, numel(asn));
    cell = min((W - 130) / k, (H - 170) / k);
    left = 112; top = 124;
    M = zeros(k, k); J = zeros(k, k);
    for e = 1:numel(ei)
        a = ei(e); b = ej(e);
        if a <= k && b <= k
            M(a, b) = ew(e); M(b, a) = ew(e);
            J(a, b) = jac(e); J(b, a) = jac(e);
        end
    end
    mx = max(M(:));
    if mx <= 0; mx = 1; end

    fid = fopen(fullfile(parts, 'matrix.svg'), 'w');
    svg_head(fid, W, H, 'Shared address space between the largest ASNs');
    w(fid, '<rect x="0" y="0" width="620" height="610" fill="#0d1526"/>');

    for i = 1:k
        y = top + (i - 1) * cell;
        name = slug{i};
        if length(name) > 15; name = [name(1:13) '..']; end
        txt(fid, left - 7, y + cell * 0.62, name, 9.5, '#8fa3bd', 'end', 'normal');
        for j = 1:k
            x = left + (j - 1) * cell;
            if i == j
                fill = '#1a2740';
                fprintf(fid, '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="#0d1526" stroke-width="1"/>\n', ...
                    x, y, cell - 1.5, cell - 1.5, fill);
                continue;
            end
            t = 0;
            if M(i, j) > 0
                t = log10(1 + M(i, j)) / log10(1 + mx);
            end
            fill = mix('#1a2740', '#ff6b5e', t.^1.35);
            fprintf(fid, '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="#0d1526" stroke-width="1"><title>AS%d %s / AS%d %s\n%s shared addresses (Jaccard %.0f%%)</title></rect>\n', ...
                x, y, cell - 1.5, cell - 1.5, fill, asn(i), esc(slug{i}), asn(j), esc(slug{j}), human(M(i, j)), 100 * J(i, j));
        end
    end

    for j = 1:k
        x = left + (j - 1) * cell + cell / 2;
        y = top - 9;
        fprintf(fid, '<text x="%.1f" y="%.1f" font-size="9.5" fill="#8fa3bd" text-anchor="start" transform="rotate(-58 %.1f %.1f)">AS%d</text>\n', ...
            x, y, x, y, asn(j));
    end

    txt(fid, left, H - 34, 'cell colour = shared address space (log scale); hover for exact numbers', 9.5, '#5f7590', 'start', 'normal');
    txt(fid, left, H - 18, sprintf('top %d ASNs by listed space', k), 9.5, '#5f7590', 'start', 'normal');
    w(fid, '</g></svg>');
    fclose(fid);
end

% ---------------------------------------------------------------------------
% prefix length histogram
% ---------------------------------------------------------------------------

function draw_prefix_hist(parts, PH)
    W = 600; H = 430;
    fid = fopen(fullfile(parts, 'prefix_hist.svg'), 'w');
    svg_head(fid, W, H, 'Prefix length distribution');
    w(fid, '<rect x="0" y="0" width="600" height="430" fill="#0d1526"/>');

    if isempty(PH)
        txt(fid, W/2, H/2, 'no prefix data', 12, '#93a4bd', 'middle', 'normal');
        w(fid, '</g></svg>'); fclose(fid); return;
    end
    len = str2double(PH(:,1)); cnt = str2double(PH(:,2));
    left = 62; right = 578; top = 30; bot = 356;
    maxc = max(cnt);
    ymax = log10(maxc + 1) * 1.08;

    % grid
    ticks = [1 10 100 1000 10000 100000];
    for t = ticks
        if t > maxc * 1.2; continue; end
        yy = bot - (bot - top) * log10(t + 1) / ymax;
        fprintf(fid, '<line x1="%d" y1="%.1f" x2="%d" y2="%.1f" stroke="#1c2a42" stroke-width="1"/>\n', left, yy, right, yy);
        txt(fid, left - 8, yy + 3.5, human(t), 9, '#5f7590', 'end', 'normal');
    end

    bw = (right - left) / numel(len);
    for q = 1:numel(len)
        x = left + (q - 1) * bw;
        hh = (bot - top) * log10(cnt(q) + 1) / ymax;
        c = '#4fb8ff';
        if len(q) == 24; c = '#ff8a5c'; end
        if len(q) <= 15; c = '#f2c14e'; end
        fprintf(fid, '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="2" fill="%s" fill-opacity="0.85"><title>/%d: %s prefixes, %s listed addresses</title></rect>\n', ...
            x + bw * 0.16, bot - hh, bw * 0.68, hh, c, len(q), human(cnt(q)), human(str2double(PH(q,3))));
        if mod(len(q), 2) == 0
            txt(fid, x + bw / 2, bot + 16, sprintf('/%d', len(q)), 9.5, '#7d90aa', 'middle', 'normal');
        end
    end

    txt(fid, 14, 20, 'listed CIDRs by prefix length (log height)', 10.5, '#93a4bd', 'start', 'normal');
    txt(fid, 14, H - 14, '/24 dominates by count; very short prefixes dominate by address space', 9.5, '#5f7590', 'start', 'normal');
    w(fid, '</g></svg>');
    fclose(fid);
end

% ---------------------------------------------------------------------------
% legend for the graph
% ---------------------------------------------------------------------------

function write_legend(parts, gnames, gcounts, nind)
    pal = owner_palette();
    fid = fopen(fullfile(parts, 'legend.html'), 'w');
    w(fid, '<div class="legend">');
    for q = 1:numel(gnames)
        if gcounts(q) == 0; continue; end
        c = pal{mod(q - 1, numel(pal)) + 1};
        w(fid, sprintf('<span class="lg"><i style="background:%s"></i>%s <small>%d ASNs</small></span>', ...
            c, esc(gnames{q}), gcounts(q)));
    end
    w(fid, sprintf('<span class="lg"><i style="background:#64748b"></i>independent <small>%d ASNs</small></span>', ...
        nind));
    w(fid, '<span class="lg"><i class="edge"></i>shared space</span>');
    w(fid, '<span class="lg"><i class="edge dash"></i>same operator</span>');
    w(fid, '</div>');
    fclose(fid);
end

function global_asn_init()
end
