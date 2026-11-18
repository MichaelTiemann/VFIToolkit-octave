function varargout = axes(varargin)
% AXES Octave compatibility shim supporting MATLAB axes(fig_handle, ...) -> axes('Parent', fig_handle, ...).
stock_axes = vfi_stock_fn('axes');
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'figure')
    args = [{'Parent', args{1}}, args(2:end)];
end
if nargout > 0
    [varargout{1:nargout}] = stock_axes(args{:});
else
    stock_axes(args{:});
end
end
