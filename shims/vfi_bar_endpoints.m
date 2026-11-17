function [x_ep, y_ep] = vfi_bar_endpoints(b_handle, series_idx)
% VFI_BAR_ENDPOINTS Compute MATLAB-equivalent b(k).XEndPoints & YEndPoints on GNU Octave & MATLAB.
if nargin < 2 || isempty(series_idx)
    series_idx = 1;
end
h = b_handle(series_idx);
if exist('OCTAVE_VERSION', 'builtin') == 0 && isprop(h, 'XEndPoints')
    x_ep = h.XEndPoints;
    y_ep = h.YEndPoints;
    return;
end

% In GNU Octave, bar hggroup stores XData and YData (and children patch vertices)
xdata = get(h, 'XData');
ydata = get(h, 'YData');
n_series = numel(b_handle);
if n_series > 1 && numel(xdata) > 1
    group_width = min(0.8, n_series / (n_series + 1.5));
    bar_w = group_width / n_series;
    offset = -group_width / 2 + (series_idx - 0.5) * bar_w;
    x_ep = xdata(:)' + offset;
else
    x_ep = xdata(:)';
end
y_ep = ydata(:)';
end
