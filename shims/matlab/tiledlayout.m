function t = tiledlayout(m, n, varargin)
% TILEDLAYOUT Octave compatibility shim storing grid dimensions in figure appdata.
fig = gcf();
t = struct('GridSize', [m, n], 'CurrentTile', 0, 'Layout', struct('Tile', 'north'));
setappdata(fig, 'vfi_tiledlayout', t);
end
