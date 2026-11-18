function [v_out, p_out] = ufhorz_raw_chunk_worker(varargin)
% UFHORZ_RAW_CHUNK_WORKER Ryzen L2/L3 cache-tiled kernel for 4D Compact UFHorz models.
% Supports both fast shared-context 2D (a_cur, z) column slicing (11 args) AND
% legacy multi-task batching (16 args), with proper singleton expansion for N_d_inner > 1.

if nargin <= 12
    ctx_file          = varargin{1};
    ctx_id            = varargin{2};
    d_outer_c         = varargin{3};
    col_start         = varargin{4};
    col_end           = varargin{5};
    bz_all            = varargin{6};
    e_val             = varargin{7};
    ReturnFnParamsVec = varargin{8};
    has_cont          = varargin{9};
    beta0             = varargin{10};
    EV_sub            = varargin{11};
    z_off             = varargin{12};

    persistent cached_id S
    if isempty(cached_id) || cached_id ~= ctx_id
        S = load('-binary', ctx_file);
        if ischar(S.ReturnFn_fh)
            S.ReturnFn_fh = str2func(S.ReturnFn_fh);
        end
        cached_id = ctx_id;
    end

    ReturnFn    = S.ReturnFn_fh;
    special_n_d = S.special_n_d;
    spec_bz_one = S.spec_bz_one;
    spec_n_e    = S.spec_n_e;
    a_gridvals  = S.a_gridvals;
    N_d_inner   = S.N_d_inner;
    N_a         = S.N_a;
    N_e_slice   = S.N_e;

    if S.N_d_outer > 1
        d_val = reshape(S.d12_gridvals(:, d_outer_c, :), [N_d_inner, size(S.d12_gridvals, 3)]);
    else
        d_val = S.d12_gridvals;
    end

    n_cols = col_end - col_start + 1;
    v_out  = zeros(1, n_cols, N_e_slice);
    p_out  = zeros(1, n_cols, N_e_slice);
    has_bz = ~isempty(bz_all);

    ParamCell = num2cell(ReturnFnParamsVec)';
    d_cells = cell(1, double(sum(special_n_d) > 0) * size(d_val, 2));
    if sum(special_n_d) > 0
        for i = 1:size(d_val, 2); d_cells{i} = d_val(:, i); end
    end
    ap_cells = cell(1, size(a_gridvals, 2));
    for i = 1:size(a_gridvals, 2); ap_cells{i} = shiftdim(a_gridvals(:, i), -1); end
    e_cells = cell(1, double(sum(spec_n_e) > 0) * size(e_val, 2));
    if sum(spec_n_e) > 0
        for i = 1:size(e_val, 2); e_cells{i} = shiftdim(e_val(:, i), -4); end
    end

    % Adaptive Ryzen L2/L3 cache tile (~2 MB max per core)
    denom_pts = max(1, N_d_inner * N_a * max(1, N_e_slice));
    blk_sz    = max(1, min(N_a, floor(262144 / denom_pts)));

    z_first = floor((col_start - 1) / N_a) + 1;
    z_last  = floor((col_end   - 1) / N_a) + 1;

    for z_global = z_first:z_last
        z_loc = z_global - z_off;
        c_lo  = max(col_start, (z_global - 1) * N_a + 1);
        c_hi  = min(col_end,   z_global * N_a);
        a_start = c_lo - (z_global - 1) * N_a;
        a_end   = c_hi - (z_global - 1) * N_a;

        bz_cells = {};
        if has_bz && sum(spec_bz_one) > 0
            bz_cells = cell(1, size(bz_all, 2));
            for i = 1:size(bz_all, 2)
                bz_cells{i} = shiftdim(bz_all(z_global, i), -3);
            end
        end

        % EV_sub has shape [1, N_a, 1, K_z_sub, 1] -> broadcast over [N_d_inner, N_a, nb, N_e_slice]
        if has_cont
            ev_z = reshape(beta0 * EV_sub(1, :, 1, z_loc, 1), [1, N_a, 1, 1]);
        end

        for i1 = a_start:blk_sz:a_end
            i2 = min(a_end, i1 + blk_sz - 1);
            nb = i2 - i1 + 1;
            out_cols = ((z_global - 1) * N_a + (i1:i2)) - col_start + 1;

            a_cur_cells = cell(1, size(a_gridvals, 2));
            for i = 1:size(a_gridvals, 2)
                a_cur_cells{i} = shiftdim(a_gridvals(i1:i2, i), -2);
            end

            F_raw = ReturnFn(d_cells{:}, ap_cells{:}, a_cur_cells{:}, bz_cells{:}, e_cells{:}, ParamCell{:});
            RHS4  = reshape(F_raw, [N_d_inner, N_a, nb, N_e_slice]);
            if has_cont
                RHS4 = RHS4 + ev_z;
            end
            [vk, pk] = max(reshape(RHS4, [N_d_inner * N_a, nb, N_e_slice]), [], 1);
            v_out(1, out_cols, :) = vk;
            p_out(1, out_cols, :) = pk;
        end
    end
    return;
end

% --- LEGACY 16-ARG MODE (for ufhorz_multi_task_worker / external callers) ---
[ReturnFn, special_n_d, n_a, spec_n_bz_one, spec_n_e, ...
    d_val, a_grid, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a, N_e_slice] = varargin{:};

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

K_z    = max(size(bz_vals_chunk, 1), 1);
v_out  = zeros(N_a, K_z, N_e_slice);
p_out  = zeros(N_a, K_z, N_e_slice);
has_bz = ~isempty(bz_vals_chunk);

a_gridvals = CreateGridvals(n_a, a_grid(:), 1);
ParamCell  = num2cell(ReturnFnParamsVec)';

d_cells = {};
if sum(special_n_d) > 0
    for i = 1:size(d_val, 2); d_cells{end+1} = d_val(:, i); end
end
ap_cells = {};
for i = 1:size(a_gridvals, 2); ap_cells{end+1} = shiftdim(a_gridvals(:, i), -1); end

denom_pts = max(1, N_d_inner * N_a * max(1, N_e_slice));
blk_sz    = max(1, min(N_a, floor(262144 / denom_pts)));

for k = 1:K_z
    bz_cells = {};
    if has_bz && sum(spec_n_bz_one) > 0
        for i = 1:size(bz_vals_chunk, 2)
            bz_cells{end+1} = shiftdim(bz_vals_chunk(k, i), -3);
        end
    end
    e_cells = {};
    if sum(spec_n_e) > 0
        for i = 1:size(e_val, 2)
            e_cells{end+1} = shiftdim(e_val(:, i), -4);
        end
    end

    if has_cont
        ev_z = reshape(beta0 * EV_chunk(1, :, 1, k, 1), [1, N_a, 1, 1]);
    end

    for i1 = 1:blk_sz:N_a
        i2 = min(N_a, i1 + blk_sz - 1);
        nb = i2 - i1 + 1;

        a_cur_cells = {};
        for i = 1:size(a_gridvals, 2)
            a_cur_cells{end+1} = shiftdim(a_gridvals(i1:i2, i), -2);
        end

        F_raw = ReturnFn(d_cells{:}, ap_cells{:}, a_cur_cells{:}, bz_cells{:}, e_cells{:}, ParamCell{:});
        RHS4  = reshape(F_raw, [N_d_inner, N_a, nb, N_e_slice]);
        if has_cont
            RHS4 = RHS4 + ev_z;
        end
        [vk, pk] = max(reshape(RHS4, [N_d_inner * N_a, nb, N_e_slice]), [], 1);
        v_out(i1:i2, k, :) = reshape(vk, [nb, 1, N_e_slice]);
        p_out(i1:i2, k, :) = reshape(pk, [nb, 1, N_e_slice]);
    end
end


end
