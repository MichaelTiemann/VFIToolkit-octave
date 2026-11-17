function hold(varargin)
% HOLD Octave compatibility shim applying hold state to active axis (and twin yyaxis if paired).
stock_hold = vfi_stock_fn('hold');
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    pair = getappdata(args{1}, 'vfi_yyaxis_pair');
    if ~isempty(pair)
        stock_hold(pair.left,  args{2:end});
        stock_hold(pair.right, args{2:end});
        return;
    end
    args{1} = vfi_active_ax(args{1});
end
stock_hold(args{:});
end
