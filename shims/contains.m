function tf = contains(str, pat, varargin)
% CONTAINS Octave compatibility shim for MATLAB R2016b+ contains(str, pat, 'IgnoreCase', tf).
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
    if ig; si = lower(si); end
    hit = false;
    for j = 1:numel(p_cell)
        pj = p_cell{j};
        if ig; pj = lower(pj); end
        if isempty(pj) || ~isempty(strfind(si, pj))
            hit = true;
            break;
        end
    end
    tf(i) = hit;
end
if is_char_in && isscalar(tf)
    tf = logical(tf(1));
end
end
