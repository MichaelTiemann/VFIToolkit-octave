function varargout = area(varargin)
% AREA Octave compatibility shim returning 1xK row vector of handles (matching MATLAB) & supporting FaceAlpha.
stock_area = vfi_stock_fn('area');
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    args{1} = vfi_active_ax(args{1});
end
fa_val = [];
clean_args = {};
k = 1;
while k <= numel(args)
    if ischar(args{k}) && strcmpi(args{k}, 'FaceAlpha') && k < numel(args)
        fa_val = args{k+1};
        k = k + 2;
    else
        clean_args{end+1} = args{k};
        k = k + 1;
    end
end
h_out = stock_area(clean_args{:});
h_out = reshape(h_out, 1, []);
if ~isempty(fa_val)
    for idx = 1:numel(h_out)
        set(findobj(h_out(idx), 'type', 'patch'), 'FaceAlpha', fa_val);
    end
end
if nargout > 0
    varargout{1} = h_out;
end
end
