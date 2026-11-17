function varargout = bar(varargin)
% BAR Octave compatibility shim: preserves [xb, yb] = bar(...) 2-output internal geometry calls,
% converts categorical X, syncs yyaxis XLim, and applies FaceAlpha/EdgeAlpha to child patches.

stock_bar = vfi_stock_fn('bar');

% Octave internal __bar__>update_data calls [xb, yb] = bar(...) with nargout >= 2 for pure geometry!
if nargout >= 2
    [varargout{1:nargout}] = stock_bar(varargin{:});
    return;
end

args = varargin;
cat_labels = {};
ax_arg = {};
ax_orig = [];

if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_orig = args{1};
    ax_arg  = {vfi_active_ax(ax_orig)};
    args    = args(2:end);
end

if ~isempty(args) && (isa(args{1}, 'categorical') || iscellstr(args{1}) || (exist('isstring', 'file') && isstring(args{1})))
    cat_labels = cellstr(args{1});
    args{1} = (1:numel(cat_labels))';
end

fa_val = [];
ea_val = [];
clean_args = {};
k = 1;
while k <= numel(args)
    if ischar(args{k}) && strcmpi(args{k}, 'FaceAlpha') && k < numel(args)
        fa_val = args{k+1};
        k = k + 2;
    elseif ischar(args{k}) && strcmpi(args{k}, 'EdgeAlpha') && k < numel(args)
        ea_val = args{k+1};
        k = k + 2;
    else
        clean_args{end+1} = args{k};
        k = k + 1;
    end
end

h_out = stock_bar(ax_arg{:}, clean_args{:});

if ~isempty(fa_val) || ~isempty(ea_val)
    for idx = 1:numel(h_out)
        ch = findobj(h_out(idx), 'type', 'patch');
        if ~isempty(fa_val); set(ch, 'FaceAlpha', fa_val); end
        if ~isempty(ea_val); set(ch, 'EdgeAlpha', ea_val); end
    end
end

if ~isempty(ax_arg); ax = ax_arg{1}; else; ax = gca(); end
if ~isempty(cat_labels)
    set(ax, 'XTick', 1:numel(cat_labels), 'XTickLabel', cat_labels);
    set(ax, 'XLim', [0.4, numel(cat_labels) + 0.6]);
end

if ~isempty(ax_orig)
    pair = getappdata(ax_orig, 'vfi_yyaxis_pair');
    if ~isempty(pair)
        xl = get(ax, 'XLim');
        set(pair.left,  'XLim', xl);
        set(pair.right, 'XLim', xl);
    end
end

if nargout == 1
    varargout{1} = h_out;
end
end
