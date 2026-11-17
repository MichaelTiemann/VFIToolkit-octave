function hold(varargin)
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    args{1} = vfi_active_ax(args{1});
end
stock_hold = vfi_stock_fn('hold');
stock_hold(args{:});
end
