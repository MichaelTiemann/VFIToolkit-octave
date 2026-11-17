function h = yline(varargin)
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax = vfi_active_ax(args{1});
    args = args(2:end);
else
    ax = gca();
end
yval = args{1};
linespec = '-k';
nv = {};
if numel(args) >= 2 && ischar(args{2}) && ~any(strcmpi(args{2}, {'Color','LineWidth','LineStyle','HandleVisibility','Alpha','Label','DisplayName'}))
    linespec = args{2};
    rest = args(3:end);
else
    rest = args(2:end);
end
k = 1;
while k <= numel(rest)
    if ischar(rest{k}) && k < numel(rest)
        if any(strcmpi(rest{k}, {'Color','LineWidth','LineStyle','HandleVisibility','DisplayName'}))
            nv(end+1:end+2) = rest(k:k+1);
        end
        k = k + 2;
    else
        k = k + 1;
    end
end
xl = get(ax, 'XLim');
was_hold = ishold(ax);
hold(ax, 'on');
stock_plot = vfi_stock_fn('plot');
h_tmp = zeros(1, numel(yval));
for idx = 1:numel(yval)
    h_tmp(idx) = stock_plot(ax, xl, [yval(idx), yval(idx)], linespec, nv{:});
end
if ~was_hold; hold(ax, 'off'); end
if nargout > 0; h = h_tmp; end
end
