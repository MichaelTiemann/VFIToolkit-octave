function hnew = copyobj(horig, hparent)
% COPYOBJ Octave compatibility shim working around Octave struct2hdl bug on bar hggroup bargroup vectors.
stock_copyobj = vfi_stock_fn('copyobj');
try
    hnew = stock_copyobj(horig, hparent);
catch
    % Workaround: temporarily clear horizontal 1xN bargroup/baseline links on hggroups, copy patches/lines/text, or re-parent
    hnew = zeros(size(horig));
    for k = 1:numel(horig)
        hk = horig(k);
        if strcmp(get(hk, 'type'), 'axes')
            ax_new = axes('Parent', hparent, ...
                'Position', get(hk, 'Position'), ...
                'XLim', get(hk, 'XLim'), 'YLim', get(hk, 'YLim'), ...
                'XTick', get(hk, 'XTick'), 'XTickLabel', get(hk, 'XTickLabel'), ...
                'YScale', get(hk, 'YScale'), 'Box', get(hk, 'Box'), ...
                'XGrid', get(hk, 'XGrid'), 'YGrid', get(hk, 'YGrid'), ...
                'FontSize', get(hk, 'FontSize'));
            builtin('set', get(ax_new, 'Title'),  'String', get(get(hk, 'Title'),  'String'), 'FontWeight', 'bold');
            builtin('set', get(ax_new, 'XLabel'), 'String', get(get(hk, 'XLabel'), 'String'), 'FontWeight', 'bold');
            builtin('set', get(ax_new, 'YLabel'), 'String', get(get(hk, 'YLabel'), 'String'), 'FontWeight', 'bold');
            hold(ax_new, 'on');
            ch = flipud(allchild(hk));
            for c = 1:numel(ch)
                ct = get(ch(c), 'type');
                if strcmp(ct, 'hggroup')
                    % Copy underlying patch children directly (bypasses bargroup 1xN struct2hdl bug!)
                    pch = flipud(findobj(ch(c), 'type', 'patch'));
                    for p = 1:numel(pch)
                        try; stock_copyobj(pch(p), ax_new); catch; end
                    end
                elseif any(strcmp(ct, {'patch', 'line', 'text', 'surface'}))
                    try; stock_copyobj(ch(c), ax_new); catch; end
                end
            end
            hnew(k) = ax_new;
        else
            hnew(k) = hk;
        end
    end
end
end
