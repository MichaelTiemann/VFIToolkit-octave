function ax = vfi_active_ax(ax_in)
% VFI_ACTIVE_AX Return active left or right twin axis if ax_in is managed by yyaxis().
if isempty(ax_in) || ~isscalar(ax_in) || ~isnumeric(ax_in) || ~ishandle(ax_in)
    ax = ax_in;
    return;
end
pair = getappdata(ax_in, 'vfi_yyaxis_pair');
if isempty(pair)
    ax = ax_in;
else
    cur = get(ancestor(ax_in, 'figure'), 'CurrentAxes');
    if isequal(cur, pair.right)
        ax = pair.right;
    else
        ax = pair.left;
    end
end
end
