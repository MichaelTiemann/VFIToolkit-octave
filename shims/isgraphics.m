function tf = isgraphics(h, gtype)
% ISGRAPHICS Octave compatibility shim mapping to ishandle().
tf = ishandle(h);
if nargin >= 2 && any(tf(:))
    for k = 1:numel(h)
        if tf(k); tf(k) = strcmpi(get(h(k), 'type'), gtype); end
    end
end
end
