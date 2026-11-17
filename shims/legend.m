function varargout = legend(varargin)
args = varargin;
stock_legend = vfi_stock_fn('legend');
stock_plot   = vfi_stock_fn('plot');
stock_patch  = vfi_stock_fn('patch');

ax_target = [];
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_target = args{1};
    args = args(2:end);
end

% Map MATLAB 'Location','best' -> 'northeast' & strip unsupported legend NV pairs ('NumColumns','Box' handled separately)
clean_args = {};
box_mode = '';
k = 1;
while k <= numel(args)
    if ischar(args{k}) && strcmpi(args{k}, 'Location') && k < numel(args)
        loc = args{k+1};
        if ischar(loc) && strcmpi(loc, 'best'); loc = 'northeast'; end
        if ischar(loc) && strcmpi(loc, 'bestoutside'); loc = 'northeastoutside'; end
        clean_args(end+1:end+2) = {'Location', loc};
        k = k + 2;
    elseif ischar(args{k}) && any(strcmpi(args{k}, {'NumColumns', 'ItemTokenSize'})) && k < numel(args)
        k = k + 2;
    elseif ischar(args{k}) && strcmpi(args{k}, 'Box') && k < numel(args)
        box_mode = args{k+1};
        k = k + 2;
    else
        clean_args{end+1} = args{k};
        k = k + 1;
    end
end
args = clean_args;

% Cross-axis yyaxis handle proxy support (both line AND bar/hggroup/patch!)
if ~isempty(args) && isnumeric(args{1}) && ~isempty(args{1}) && all(ishandle(args{1}(:)))
    h_vec = args{1}(:)';
    if isempty(ax_target)
        ax_target = ancestor(h_vec(1), 'axes');
    end
    pair = getappdata(ax_target, 'vfi_yyaxis_pair');
    if ~isempty(pair); ax_target = pair.right; end

    was_hold = ishold(ax_target);
    hold(ax_target, 'on');
    for idx = 1:numel(h_vec)
        h_i = h_vec(idx);
        if ~isequal(ancestor(h_i, 'axes'), ax_target)
            htype = get(h_i, 'type');
            dn    = get(h_i, 'DisplayName');
            if strcmp(htype, 'line')
                h_vec(idx) = stock_plot(ax_target, NaN, NaN, ...
                    'Color', get(h_i, 'Color'), 'LineStyle', get(h_i, 'LineStyle'), ...
                    'LineWidth', get(h_i, 'LineWidth'), 'Marker', get(h_i, 'Marker'), ...
                    'MarkerFaceColor', get(h_i, 'MarkerFaceColor'), 'MarkerSize', get(h_i, 'MarkerSize'), ...
                    'DisplayName', dn);
            elseif strcmp(htype, 'hggroup') || strcmp(htype, 'patch')
                fc = [0.2 0.5 0.8];
                if isprop(h_i, 'FaceColor'); fc = get(h_i, 'FaceColor');
                else
                    ch = get(h_i, 'Children');
                    if ~isempty(ch) && isprop(ch(1), 'FaceColor'); fc = get(ch(1), 'FaceColor'); end
                end
                if ischar(fc); fc = [0.2 0.5 0.8]; end
                h_vec(idx) = stock_patch(ax_target, NaN, NaN, fc, 'DisplayName', dn);
            end
        end
    end
    if ~was_hold; hold(ax_target, 'off'); end
    args{1} = h_vec;
elseif ~isempty(ax_target)
    pair = getappdata(ax_target, 'vfi_yyaxis_pair');
    if ~isempty(pair) && isempty(args)
        % legend(ax) with no handle list on a yyaxis: collect all DisplayName children from left + right!
        ch_l = flipud(get(pair.left,  'Children'));
        ch_r = flipud(get(pair.right, 'Children'));
        cand = [ch_l(:); ch_r(:)];
        keep = [];
        for idx = 1:numel(cand)
            if isprop(cand(idx), 'HandleVisibility') && strcmp(get(cand(idx), 'HandleVisibility'), 'on') ...
                    && isprop(cand(idx), 'DisplayName') && ~isempty(get(cand(idx), 'DisplayName'))
                keep(end+1) = cand(idx);
            end
        end
        if ~isempty(keep)
            if nargout > 0
                [varargout{1:nargout}] = legend(pair.right, keep);
            else
                legend(pair.right, keep);
            end
            return;
        end
    end
end

if ~isempty(ax_target); call_args = [{ax_target}, args]; else; call_args = args; end
if nargout > 0
    [varargout{1:nargout}] = stock_legend(call_args{:});
    if strcmpi(box_mode, 'off'); legend(ax_target, 'boxoff'); end
else
    stock_legend(call_args{:});
    if strcmpi(box_mode, 'off'); legend('boxoff'); end
end
end
