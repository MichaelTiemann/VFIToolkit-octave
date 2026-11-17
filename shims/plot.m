function varargout = plot(varargin)
% PLOT Octave compatibility shim: yyaxis routing + categorical X/Y + MarkerIndices filter.
args = varargin;
ax_arg = {};
cat_labels = {};

if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_arg = {vfi_active_ax(args{1})};
    args = args(2:end);
end

if ~isempty(args) && isa(args{1}, 'categorical')
    [args{1}, cat_labels] = vfi_cat2num(args{1});
end
if numel(args) >= 2 && isa(args{2}, 'categorical')
    args{2} = vfi_cat2num(args{2});
end

clean_args = {};
k = 1;
while k <= numel(args)
    if ischar(args{k}) && strcmpi(args{k}, 'MarkerIndices') && k < numel(args)
        k = k + 2;
    else
        clean_args{end+1} = args{k};
        k = k + 1;
    end
end

stock_fn = vfi_stock_fn('plot');
if nargout > 0
    [varargout{1:nargout}] = stock_fn(ax_arg{:}, clean_args{:});
else
    stock_fn(ax_arg{:}, clean_args{:});
end

if ~isempty(cat_labels)
    if ~isempty(ax_arg); ax = ax_arg{1}; else; ax = gca(); end
    set(ax, 'XTick', 1:numel(cat_labels), 'XTickLabel', cat_labels);
end
end
