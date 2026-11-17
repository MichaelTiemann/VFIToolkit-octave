function tf = endsWith(str, pat, varargin)
ig = false;
for k = 1:2:(numel(varargin)-1)
    if ischar(varargin{k}) && strcmpi(varargin{k}, 'IgnoreCase')
        ig = logical(varargin{k+1});
    end
end
is_char_in = ischar(str);
s_cell = cellstr(str);
p_cell = cellstr(pat);
tf = false(size(s_cell));
for i = 1:numel(s_cell)
    si = s_cell{i};
    ns = numel(si);
    for j = 1:numel(p_cell)
        pj = p_cell{j};
        np = numel(pj);
        if np == 0
            tf(i) = true; break;
        elseif ns >= np
            tail = si(ns - np + 1 : ns);
            if (ig && strcmpi(tail, pj)) || (~ig && strcmp(tail, pj))
                tf(i) = true; break;
            end
        end
    end
end
if is_char_in && isscalar(tf); tf = logical(tf(1)); end
end
