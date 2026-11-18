function varargout = xticks(varargin)
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_orig = args{1};
    args{1} = vfi_active_ax(ax_orig);
    if strcmp('xticks', 'xlim') && numel(args) >= 2
        pair = getappdata(ax_orig, 'vfi_yyaxis_pair');
        if ~isempty(pair)
            shim_dir = fileparts(mfilename('fullpath'));
            unwind_protect
                rmpath(shim_dir);
                xlim(pair.left, args{2:end});
                xlim(pair.right, args{2:end});
            unwind_protect_cleanup
                addpath(shim_dir, '-begin');
            end_unwind_protect
            return;
        end
    end
end
stock_fn = vfi_stock_fn('xticks');
if nargout > 0
    [varargout{1:nargout}] = stock_fn(args{:});
else
    stock_fn(args{:});
end
end
