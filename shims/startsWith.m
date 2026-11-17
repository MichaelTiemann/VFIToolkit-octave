function tf = startsWith(str, pat, varargin)
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
    for j = 1:numel(p_cell)
        pj = p_cell{j};
        if isempty(pj) || (ig && strncmpi(si, pj, numel(pj))) || (~ig && strncmp(si, pj, numel(pj)))
            tf(i) = true;
            break;
        end
    end
end
if is_char_in && isscalar(tf); tf = logical(tf(1)); end
end
