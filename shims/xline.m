function h = xline(xval, linespec, varargin)
% XLINE Octave compatibility shim ignoring unsupported MATLAB text label Name-Value args.
if nargin < 2 || isempty(linespec)
    linespec = '-k';
end
ax = gca();
yl = ylim(ax);
was_hold = ishold(ax);
hold(ax, 'on');
h_tmp = plot(ax, [xval, xval], yl, linespec, 'HandleVisibility', 'off');
if ~was_hold
    hold(ax, 'off');
end
if nargout > 0
    h = h_tmp;
end
end
