function varargout = arrayfun_expand(ReturnFn, varargin)
% ARRAYFUN_EXPAND L2-cache-tiled implicit singleton expansion for GNU Octave arrayfun.
% Keeps expanded working tiles <= 256 KB per array so workers never OOM or thrash DRAM.

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

n_inputs = numel(varargin);
n_outs   = max(1, nargout);

% 1. Infer full broadcast shape across ALL non-scalar numeric/logical inputs
max_nd = 2;
is_arr = false(1, n_inputs);
for i = 1:n_inputs
    vi = varargin{i};
    if (isnumeric(vi) || islogical(vi)) && ~isscalar(vi)
        if isempty(vi)
            error('arrayfun_expand: empty array input at position %d', i);
        end
        is_arr(i) = true;
        max_nd = max(max_nd, ndims(vi));
    end
end

% Pure scalar call fast path
if ~any(is_arr)
    varargout = cell(1, n_outs);
    [varargout{:}] = builtin('arrayfun', ReturnFn, varargin{:});
    return;
end

full_sz  = ones(1, max_nd);
arg_sz   = cell(1, n_inputs);
for i = 1:n_inputs
    s = ones(1, max_nd);
    if is_arr(i)
        si = size(varargin{i});
        s(1:numel(si)) = si;
        bad = (s ~= 1) & (full_sz ~= 1) & (s ~= full_sz);
        if any(bad)
            error('arrayfun_expand: non-conformant dimensions for implicit expansion');
        end
        full_sz = max(full_sz, s);
    end
    arg_sz{i} = s;
end

N_total = prod(full_sz);

% 2. Small tensor fast path (fits directly in L2 cache: <= 32,768 elements = 256 KB)
TILE_TARGET = 32768;
if N_total <= TILE_TARGET
    ones_full = ones(full_sz);
    exp_args  = varargin;
    for i = 1:n_inputs
        if is_arr(i)
            exp_args{i} = bsxfun(@times, varargin{i}, ones_full);
        end
    end
    varargout = cell(1, n_outs);
    [varargout{:}] = builtin('arrayfun', ReturnFn, exp_args{:});
    return;
end

% 3. Partition into inner contiguous dims + tiled outer column-major dims
split_d = max_nd;
while split_d > 1 && prod(full_sz(1:split_d-1)) > TILE_TARGET
    split_d = split_d - 1;
end

sz_inner = full_sz(1:split_d-1);
sz_outer = full_sz(split_d:max_nd);
N_inner  = prod(sz_inner); % prod([]) == 1 when split_d == 1
N_outer  = prod(sz_outer);
n_in_d   = numel(sz_inner);
n_out_d  = numel(sz_outer);

tile_cols = max(1, min(N_outer, floor(TILE_TARGET / N_inner)));

% Pre-reshape array inputs to 2D [nA_inner, nA_outer] views (O(1) metadata in Octave)
arr_2d   = cell(1, n_inputs);
sA_in_c  = cell(1, n_inputs);
sA_out_c = cell(1, n_inputs);
has_out  = false(1, n_inputs);

for i = 1:n_inputs
    if is_arr(i)
        s        = arg_sz{i};
        s_in     = s(1:n_in_d);
        s_out    = s(n_in_d+1:max_nd);
        sA_in_c{i}  = s_in;
        sA_out_c{i} = s_out;
        nA_out   = prod(s_out);
        has_out(i) = (nA_out > 1);
        arr_2d{i}  = reshape(varargin{i}, prod(s_in), nA_out);
    end
end

varargout = cell(1, n_outs);

for c0 = 1:tile_cols:N_outer
    c1  = min(N_outer, c0 + tile_cols - 1);
    idx = c0:c1;
    B   = numel(idx);

    if n_in_d == 0
        tile_sz = [1, B];
    else
        tile_sz = [sz_inner, B];
    end
    ones_tile = ones(tile_sz);

    if n_out_d >= 2
        sub_out = cell(1, n_out_d);
        [sub_out{:}] = ind2sub(sz_outer, idx);
    end

    t_args = varargin;
    for i = 1:n_inputs
        if is_arr(i)
            if ~has_out(i)
                % Varies only across inner dims: broadcast directly onto tile
                t_args{i} = bsxfun(@times, varargin{i}, ones_tile);
            else
                s_out = sA_out_c{i};
                if n_out_d == 1
                    idx_A = idx;
                else
                    sub_A = sub_out;
                    for d = 1:n_out_d
                        if s_out(d) == 1
                            sub_A{d} = ones(1, B);
                        end
                    end
                    idx_A = sub2ind(s_out, sub_A{:});
                end
                slice_2d = arr_2d{i}(:, idx_A);
                if n_in_d == 0
                    sub_arr = reshape(slice_2d, [1, B]);
                else
                    sub_arr = reshape(slice_2d, [sA_in_c{i}, B]);
                end
                t_args{i} = bsxfun(@times, sub_arr, ones_tile);
            end
        end
    end

    t_out = cell(1, n_outs);
    [t_out{:}] = builtin('arrayfun', ReturnFn, t_args{:});

    if c0 == 1
        % Allocate exact output class/precision from first tile
        for o = 1:n_outs
            varargout{o} = zeros(N_inner, N_outer, class(t_out{o}));
        end
    end
    for o = 1:n_outs
        varargout{o}(:, idx) = reshape(t_out{o}, N_inner, B);
    end
end

for o = 1:n_outs
    varargout{o} = reshape(varargout{o}, full_sz);
end


end
