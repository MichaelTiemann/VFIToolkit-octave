function varargout = legend(varargin)
% LEGEND Octave compatibility shim delegating directly to stock legend().
% Native Octave legend(hax, hobjs, 'Location', ...) already accepts handles across twin axes!
stock_legend = vfi_stock_fn('legend');

args = varargin;
ax_arg = [];
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_arg = args{1};
    args = args(2:end);
end

clean_args = {};
k = 1;
while k <= numel(args)
    if ischar(args{k}) && strcmpi(args{k}, 'ItemTokenSize') && k < numel(args)
        k = k + 2;
    elseif ischar(args{k}) && strcmpi(args{k}, 'Location') && k < numel(args)
        loc = args{k+1};
        if ischar(loc) && strcmpi(loc, 'best'); loc = 'northeast'; end
        if ischar(loc) && strcmpi(loc, 'bestoutside'); loc = 'northeastoutside'; end
        clean_args(end+1:end+2) = {'Location', loc};
        k = k + 2;
    else
        clean_args{end+1} = args{k};
        k = k + 1;
    end
end

% If called on a yyaxis twin without explicit handles or labels (e.g. legend(ax2, 'Location', ...)),
% gather labeled objects from both left and right twin axes in plot order and attach to pair.right:
if ~isempty(ax_arg)
    pair = getappdata(ax_arg, 'vfi_yyaxis_pair');
    if ~isempty(pair)
        ax_arg = pair.right;
        has_handles_or_labels = ~isempty(clean_args) && ...
            ((isnumeric(clean_args{1}) && all(ishghandle(clean_args{1}(:)))) || iscellstr(clean_args{1}));
        if ~has_handles_or_labels
            ch = [flipud(get(pair.left, 'Children')); flipud(get(pair.right, 'Children'))];
            valid_t = {'hggroup', 'line', 'patch', 'scatter', 'surface'};
            keep = [];
            for c = 1:numel(ch)
                if any(strcmp(get(ch(c), 'type'), valid_t)) && strcmp(get(ch(c), 'HandleVisibility'), 'on') ...
                        && ~isempty(get(ch(c), 'DisplayName'))
                    keep(end+1) = ch(c); %#ok<AGROW>
                end
            end
            if ~isempty(keep)
                clean_args = [{keep}, clean_args];
            end
        end
    end
    call_args = [{ax_arg}, clean_args];
else
    call_args = clean_args;
end

if nargout > 0
    [varargout{1:nargout}] = stock_legend(call_args{:});
else
    stock_legend(call_args{:});
end
end
