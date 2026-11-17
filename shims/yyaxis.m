function yyaxis(varargin)
% YYAXIS Octave twin-axes shim preserving transparent overlay & NextPlot='replacechildren'.
if nargin == 1
    ax = gca();
    side = varargin{1};
elseif nargin == 2
    ax = varargin{1};
    side = varargin{2};
else
    error('yyaxis: expected 1 or 2 arguments');
end

pair = getappdata(ax, 'vfi_yyaxis_pair');
if isempty(pair)
    ax_left = ax;
    builtin('set', ax_left, 'YAxisLocation', 'left', 'Box', 'off', 'NextPlot', 'replacechildren');
    ax_right = axes('Parent', get(ax_left, 'Parent'), ...
        'Position', get(ax_left, 'Position'), ...
        'Color', 'none', ...
        'YAxisLocation', 'right', ...
        'XAxisLocation', 'bottom', ...
        'XTick', [], ...
        'Box', 'off', ...
        'NextPlot', 'replacechildren');
    builtin('set', ax_right, 'XLim', get(ax_left, 'XLim'));
    pair = struct('left', ax_left, 'right', ax_right);
    setappdata(ax_left,  'vfi_yyaxis_pair', pair);
    setappdata(ax_right, 'vfi_yyaxis_pair', pair);
end

% Always keep right overlay transparent and position-synced with left axes
builtin('set', pair.right, 'Color', 'none', 'Position', get(pair.left, 'Position'), 'XLim', get(pair.left, 'XLim'));

if strcmpi(side, 'left')
    setappdata(pair.left,  'vfi_yyaxis_active', pair.left);
    setappdata(pair.right, 'vfi_yyaxis_active', pair.left);
    axes(pair.left);
elseif strcmpi(side, 'right')
    setappdata(pair.left,  'vfi_yyaxis_active', pair.right);
    setappdata(pair.right, 'vfi_yyaxis_active', pair.right);
    axes(pair.right);
else
    error('yyaxis: side must be "left" or "right"');
end
end
