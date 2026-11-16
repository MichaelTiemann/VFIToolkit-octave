function h = yline(yval, linespec, varargin)
% YLINE Octave compatibility shim ignoring unsupported MATLAB text label Name-Value args.
if nargin < 2 || isempty(linespec)
    linespec = '-k';
end
ax = gca();
xl = xlim(ax);
was_hold = ishold(ax);
hold(ax, 'on');
h_tmp = plot(ax, xl, [yval, yval], linespec, 'HandleVisibility', 'off');
if ~was_hold
    hold(ax, 'off');
end
if nargout > 0
    h = h_tmp;
end
end
