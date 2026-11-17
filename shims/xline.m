function h = xline(varargin)
% XLINE Octave compatibility shim supporting optional leading axes handle, categorical X, & MATLAB label args.
args = varargin;
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax = args{1};
    args = args(2:end);
else
    ax = gca();
end
xval = args{1};
if isa(xval, 'categorical'); xval = vfi_cat2num(xval); end
linespec = '-k';
nv = {};
if numel(args) >= 2 && ischar(args{2}) && ~any(strcmpi(args{2}, {'Color','LineWidth','LineStyle','HandleVisibility','Alpha','Label'}))
    linespec = args{2};
    rest = args(3:end);
else
    rest = args(2:end);
end
k = 1;
while k <= numel(rest)
    if ischar(rest{k}) && k < numel(rest)
        if any(strcmpi(rest{k}, {'Color','LineWidth','LineStyle','HandleVisibility'}))
            nv(end+1:end+2) = rest(k:k+1);
        end
        k = k + 2;
    else
        k = k + 1;
    end
end
yl = ylim(ax);
was_hold = ishold(ax);
hold(ax, 'on');
h_tmp = zeros(1, numel(xval));
for idx = 1:numel(xval)
    h_tmp(idx) = plot(ax, [xval(idx), xval(idx)], yl, linespec, nv{:});
end
if ~was_hold; hold(ax, 'off'); end
if nargout > 0; h = h_tmp; end
end
