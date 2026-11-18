function [num_val, labels] = vfi_cat2num(x)
% VFI_CAT2NUM Convert Tablicious categorical (or cellstr) coordinates to 1-based numeric indices.
labels = {};
if isa(x, 'categorical')
    cats = categories(x);
    strs = cellstr(x);
    num_val = zeros(size(strs));
    for k = 1:numel(strs)
        idx = find(strcmp(cats, strs{k}), 1);
        if isempty(idx); num_val(k) = NaN; else; num_val(k) = idx; end
    end
    labels = cats;
else
    num_val = double(x);
end
end
