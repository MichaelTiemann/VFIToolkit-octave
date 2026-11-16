function [F, full_sz] = arrayfun_expand(ReturnFn, varargin)
% ARRAYFUN_EXPAND Broadcast orthogonal/N-D state grids for scalar Octave arrayfun.
% Scans backward to preserve embedded scalar state arguments (e.g., whicha = 1, 2
% or lowmemory size-1 shock slices) without misclassifying subsequent state grids.

n_inputs = length(varargin);

% Scan backward from end to find the last non-scalar array argument
last_arr_idx = 0;
for i = n_inputs:-1:1
    a = varargin{i};
    if (isnumeric(a) || islogical(a)) && ~isscalar(a)
        last_arr_idx = i;
        break;
    end
end

% Pure scalar call: evaluate directly
if last_arr_idx == 0
    F = builtin('arrayfun', ReturnFn, varargin{:});
    full_sz = [1, 1];
    return;
end

param_idx = last_arr_idx + 1;

% Compute broadcasted state-space shape across 1..last_arr_idx
max_nd = 2;
for i = 1:last_arr_idx
    max_nd = max(max_nd, ndims(varargin{i}));
end
full_sz = ones(1, max_nd);

for i = 1:last_arr_idx
    sz = size(varargin{i});
    sz(end+1:max_nd) = 1;
    for d = 1:max_nd
        if full_sz(d) == 1
            full_sz(d) = sz(d);
        elseif sz(d) ~= 1 && sz(d) ~= full_sz(d)
            error('arrayfun: non-conformant array dimensions for implicit expansion');
        end
    end
end

% Expand all grid/embedded-scalar arguments over 1..last_arr_idx to full_sz
one_grid = builtin('ones', full_sz);
expanded_args = cell(1, last_arr_idx);
for i = 1:last_arr_idx
    expanded_args{i} = bsxfun(@times, varargin{i}, one_grid);
end

F = builtin('arrayfun', ReturnFn, expanded_args{:}, varargin{param_idx:end});

end
