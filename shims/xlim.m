function varargout = xlim(varargin)
args = varargin;
stock_xlim = vfi_stock_fn('xlim');
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_orig = args{1};
    if numel(args) >= 2
        pair = getappdata(ax_orig, 'vfi_yyaxis_pair');
        if ~isempty(pair)
            stock_xlim(pair.left, args{2:end});
            stock_xlim(pair.right, args{2:end});
            return;
        end
    end
    args{1} = vfi_active_ax(ax_orig);
end
if nargout > 0
    [varargout{1:nargout}] = stock_xlim(args{:});
else
    stock_xlim(args{:});
end
end
