function varargout = bar(varargin)
% BAR Octave compatibility shim accepting Tablicious categorical X-axes.
args = varargin;
cat_labels = {};
ax_arg = {};

idx = 1;
if ~isempty(args) && isscalar(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_arg = args(1);
    args = args(2:end);
end

if ~isempty(args) && (isa(args{1}, 'categorical') || iscellstr(args{1}) || isstring(args{1}))
    if isa(args{1}, 'categorical')
        cat_labels = cellstr(args{1});
    else
        cat_labels = cellstr(args{1});
    end
    args{1} = (1:numel(cat_labels))';
end

n_out = nargout;
if n_out > 0
    [varargout{1:n_out}] = builtin('bar', ax_arg{:}, args{:});
else
    h_tmp = builtin('bar', ax_arg{:}, args{:});
    if nargout > 0; varargout{1} = h_tmp; end
end

if ~isempty(cat_labels)
    if ~isempty(ax_arg)
        ax = ax_arg{1};
    else
        ax = gca();
    end
    set(ax, 'XTick', 1:numel(cat_labels), 'XTickLabel', cat_labels);
end
end
