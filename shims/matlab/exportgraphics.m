function exportgraphics(h_in, filename, varargin)
% EXPORTGRAPHICS Octave compatibility shim:
%   - Full figure handle: renders 300-DPI PNG/PDF via print()
%   - Single axes handle: renders parent figure to 300-DPI RGB raster and crops to axes + labels!

is_single_ax = ~isempty(h_in) && isscalar(h_in) && ishandle(h_in) && strcmp(get(h_in, 'type'), 'axes');
if isempty(h_in) || ~ishandle(h_in(1))
    fig_handle = gcf();
else
    fig_handle = ancestor(h_in(1), 'figure');
    if isempty(fig_handle); fig_handle = gcf(); end
end

% Keep all yyaxis right overlays transparent and aligned before capture
all_ax = findall(fig_handle, 'type', 'axes');
for k = 1:numel(all_ax)
    pair = getappdata(all_ax(k), 'vfi_yyaxis_pair');
    if ~isempty(pair) && ishandle(pair.right)
        builtin('set', pair.right, 'Color', 'none', 'Position', get(pair.left, 'Position'));
    end
end

avail = available_graphics_toolkits();
try
    cur_tk = get(fig_handle, '__graphics_toolkit__');
catch
    cur_tk = graphics_toolkit();
end
if strcmp(cur_tk, 'fltk')
    if any(strcmp(avail, 'qt'))
        graphics_toolkit(fig_handle, 'qt');
    elseif any(strcmp(avail, 'gnuplot'))
        graphics_toolkit(fig_handle, 'gnuplot');
    end
end

dpi = 300;
for k = 1:(numel(varargin) - 1)
    if ischar(varargin{k}) && strcmpi(varargin{k}, 'Resolution')
        dpi = varargin{k + 1};
    end
end

[~, ~, ext] = fileparts(filename);
if is_single_ax && ~strcmpi(ext, '.pdf')
    % Temporarily hide sibling axes (except our target ax, its yyaxis twin, and its legend) so labels never bleed!
    ax_keep = h_in;
    pair = getappdata(h_in, 'vfi_yyaxis_pair');
    if ~isempty(pair)
        ax_keep = [pair.left, pair.right];
    end
    pos_norm = get(ax_keep(1), 'Position'); % [x, y, w, h] in normalized figure units

    % Keep legends whose center falls within expanded panel bounds
    x_lo = max(0, pos_norm(1) - 0.075);
    x_hi = min(1, pos_norm(1) + pos_norm(3) + 0.085);
    y_lo = max(0, pos_norm(2) - 0.165);
    y_hi = min(1, pos_norm(2) + pos_norm(4) + 0.095);

    vis_objs  = [];
    vis_state = {};
    fig_ch = allchild(fig_handle);
    for k = 1:numel(fig_ch)
        ch = fig_ch(k);
        if any(ch == ax_keep); continue; end
        ctype = get(ch, 'type');
        if strcmp(ctype, 'axes')
            tag_c = get(ch, 'Tag');
            p_c   = get(ch, 'Position');
            cx    = p_c(1) + 0.5 * p_c(3);
            cy    = p_c(2) + 0.5 * p_c(4);
            if strcmpi(tag_c, 'legend') && cx >= x_lo && cx <= x_hi && cy >= y_lo && cy <= y_hi
                continue;
            end
            all_sub = findall(ch);
            for s = 1:numel(all_sub)
                if isprop(all_sub(s), 'Visible')
                    vis_objs(end+1)  = all_sub(s); %#ok<AGROW>
                    vis_state{end+1} = get(all_sub(s), 'Visible'); %#ok<AGROW>
                    builtin('set', all_sub(s), 'Visible', 'off');
                end
            end
        end
    end

    unwind_protect
        drawnow();
        img = print(fig_handle, '-RGBImage', sprintf('-r%d', dpi));
    unwind_protect_cleanup
        for s = 1:numel(vis_objs)
            if ishandle(vis_objs(s))
                builtin('set', vis_objs(s), 'Visible', vis_state{s});
            end
        end
    end_unwind_protect

    % Auto-crop non-white pixels with clean 24px white margin
    non_white = any(img < 252, 3);
    rows = find(any(non_white, 2));
    cols = find(any(non_white, 1));
    if ~isempty(rows) && ~isempty(cols)
        H = size(img, 1); W = size(img, 2);
        pad = 24;
        r1 = max(1, min(rows) - pad); r2 = min(H, max(rows) + pad);
        c1 = max(1, min(cols) - pad); c2 = min(W, max(cols) + pad);
        img = img(r1:r2, c1:c2, :);
    end
    imwrite(img, filename);
    return;
end

if strcmpi(ext, '.pdf'); dev = '-dpdf'; else; dev = '-dpng'; end
print(fig_handle, filename, dev, sprintf('-r%d', dpi));
end
