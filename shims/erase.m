function out = erase(str, pat)
p_cell = cellstr(pat);
out = str;
for j = 1:numel(p_cell)
    out = strrep(out, p_cell{j}, '');
end
end
