function ax = nexttile(tile_idx)
% NEXTTILE Octave compatibility shim mapping tiledlayout/nexttile to subplot().
fig = gcf();
t = getappdata(fig, 'vfi_tiledlayout');
if isempty(t)
    t = struct('GridSize', [2, 2], 'CurrentTile', 0);
end
if nargin >= 1 && isnumeric(tile_idx)
    t.CurrentTile = tile_idx;
else
    t.CurrentTile = t.CurrentTile + 1;
end
setappdata(fig, 'vfi_tiledlayout', t);
ax = subplot(t.GridSize(1), t.GridSize(2), t.CurrentTile);
end
