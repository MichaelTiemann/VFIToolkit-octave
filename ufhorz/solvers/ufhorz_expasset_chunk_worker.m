function [v_out, p_out] = ufhorz_expasset_chunk_worker(varargin)
% UFHORZ_EXPASSET_CHUNK_WORKER Ryzen L2/L3 cache-tiled & 2D (a1, z) load-balanced kernel.
% Supports both 12-arg shared-context 2D column slicing AND 18-arg multi_task_worker tuples.

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
    n_a1        = S.n_a1;
    n_a2        = S.n_a2;
    spec_bz_one = S.spec_bz_one;
    spec_n_e    = S.spec_n_e;
    a1_gridvals = S.a1_gridvals;
    a2_gridvals = S.a2_gridvals;
    N_d1        = S.N_d1;
    N_d2        = S.N_d2;
    N_d_inner   = S.N_d_inner;
    N_a1        = S.N_a1;
    N_a2        = S.N_a2;
    N_e_slice   = S.N_e;

    if S.N_d_outer > 1
        d_val = reshape(S.d12_gridvals(:, d_outer_c, :), [N_d_inner, size(S.d12_gridvals, 3)]);
    else
        d_val = S.d12_gridvals;
    end

    n_cols = col_end - col_start + 1;
    v_out  = zeros(N_a2, n_cols, N_e_slice);
    p_out  = zeros(N_a2, n_cols, N_e_slice);
    has_bz = ~isempty(bz_all);

    ParamCell = num2cell(ReturnFnParamsVec)';
    d_cells = cell(1, double(sum(special_n_d) > 0) * size(d_val, 2));
    if sum(special_n_d) > 0
        for i = 1:size(d_val, 2); d_cells{i} = d_val(:, i); end
    end
    a1p_cells = cell(1, double(sum(n_a1) > 0) * size(a1_gridvals, 2));
    if sum(n_a1) > 0
        for i = 1:size(a1_gridvals, 2); a1p_cells{i} = shiftdim(a1_gridvals(:, i), -1); end
    end
    a2_cells = cell(1, double(sum(n_a2) > 0) * size(a2_gridvals, 2));
    if sum(n_a2) > 0
        for i = 1:size(a2_gridvals, 2); a2_cells{i} = shiftdim(a2_gridvals(:, i), -3); end
    end
    e_cells = cell(1, double(sum(spec_n_e) > 0) * size(e_val, 2));
    if sum(spec_n_e) > 0
        for i = 1:size(e_val, 2); e_cells{i} = shiftdim(e_val(:, i), -5); end
    end

    denom_pts = max(1, N_d_inner * N_a1 * max(1, N_a2) * max(1, N_e_slice));
    blk_sz    = max(1, min(N_a1, floor(2097152 / denom_pts)));

    z_first = floor((col_start - 1) / N_a1) + 1;
    z_last  = floor((col_end   - 1) / N_a1) + 1;
    N_e_ev  = 1;
    if has_cont; N_e_ev = size(EV_sub, 6); end

    for z_global = z_first:z_last
        z_loc = z_global - z_off;
        c_lo  = max(col_start, (z_global - 1) * N_a1 + 1);
        c_hi  = min(col_end,   z_global * N_a1);
        a1_start = c_lo - (z_global - 1) * N_a1;
        a1_end   = c_hi - (z_global - 1) * N_a1;

        bz_cells = {};
        if has_bz && sum(spec_bz_one) > 0
            bz_cells = cell(1, size(bz_all, 2));
            for i = 1:size(bz_all, 2)
                bz_cells{i} = shiftdim(bz_all(z_global, i), -4);
            end
        end

        if has_cont
            N_d_ev   = size(EV_sub, 2);
            N_a2_ev  = size(EV_sub, 4);
            ev_z_raw = beta0 * reshape(EV_sub(1, :, :, :, z_loc, :), [1, N_d_ev, N_a1, 1, N_a2_ev, N_e_ev]);
        end

        for i1 = a1_start:blk_sz:a1_end
            i2 = min(a1_end, i1 + blk_sz - 1);
            nb = i2 - i1 + 1;
            out_cols = ((z_global - 1) * N_a1 + (i1:i2)) - col_start + 1;

            a1_cur_cells = {};
            if sum(n_a1) > 0
                a1_cur_cells = cell(1, size(a1_gridvals, 2));
                for i = 1:size(a1_gridvals, 2)
                    a1_cur_cells{i} = shiftdim(a1_gridvals(i1:i2, i), -2);
                end
            end

            F_raw = ReturnFn(d_cells{:}, a1p_cells{:}, a1_cur_cells{:}, a2_cells{:}, bz_cells{:}, e_cells{:}, ParamCell{:});
            a2_sz = size(F_raw, 4);

            if has_cont
                F_split  = reshape(F_raw, [N_d1, N_d2, N_a1, nb, a2_sz, N_e_slice]);
                RHS      = F_split + ev_z_raw;
                N_a2_out = max(a2_sz, N_a2_ev);
                [vk, pk] = max(reshape(RHS, [N_d_inner * N_a1, nb, N_a2_out, N_e_slice]), [], 1);
                if N_a2_out == 1 && N_a2 > 1
                    v_out(:, out_cols, :) = repmat(reshape(vk, [1, nb, N_e_slice]), [N_a2, 1, 1]);
                    p_out(:, out_cols, :) = repmat(reshape(pk, [1, nb, N_e_slice]), [N_a2, 1, 1]);
                else
                    v_out(:, out_cols, :) = permute(reshape(vk, [nb, N_a2, N_e_slice]), [2, 1, 3]);
                    p_out(:, out_cols, :) = permute(reshape(pk, [nb, N_a2, N_e_slice]), [2, 1, 3]);
                end
            else
                [vk, pk] = max(reshape(F_raw, [N_d_inner * N_a1, nb, a2_sz, N_e_slice]), [], 1);
                if a2_sz == 1 && N_a2 > 1
                    v_out(:, out_cols, :) = repmat(reshape(vk, [1, nb, N_e_slice]), [N_a2, 1, 1]);
                    p_out(:, out_cols, :) = repmat(reshape(pk, [1, nb, N_e_slice]), [N_a2, 1, 1]);
                else
                    v_out(:, out_cols, :) = permute(reshape(vk, [nb, N_a2, N_e_slice]), [2, 1, 3]);
                    p_out(:, out_cols, :) = permute(reshape(pk, [nb, N_a2, N_e_slice]), [2, 1, 3]);
                end
            end
        end
    end
    return;
end

% --- LEGACY 18-ARG MODE (for ufhorz_multi_task_worker / Solve_VFI_PhaseSplit) ---
[ReturnFn, special_n_d, n_a1, n_a2, spec_n_bz_one, spec_n_e, ...
    d_val, a1_gridvals, a2_gridvals, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a1, N_a2, N_e_slice] = varargin{:};

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

K_z    = max(size(bz_vals_chunk, 1), 1);
N_a    = N_a1 * N_a2;
v_out  = zeros(N_a, K_z, N_e_slice);
p_out  = zeros(N_a, K_z, N_e_slice);
has_bz = ~isempty(bz_vals_chunk);

ParamCell = num2cell(ReturnFnParamsVec)';
d_cells = {};
if sum(special_n_d) > 0
    for i = 1:size(d_val, 2); d_cells{end+1} = d_val(:, i); end
end
a1p_cells = {};
if sum(n_a1) > 0
    for i = 1:size(a1_gridvals, 2); a1p_cells{end+1} = shiftdim(a1_gridvals(:, i), -1); end
end
a2_cells = {};
if sum(n_a2) > 0
    for i = 1:size(a2_gridvals, 2); a2_cells{end+1} = shiftdim(a2_gridvals(:, i), -3); end
end

denom_pts = max(1, N_d_inner * N_a1 * max(1, N_a2) * max(1, N_e_slice));
blk_sz    = max(1, min(N_a1, floor(2097152 / denom_pts)));
N_e_ev    = 1;
if has_cont; N_e_ev = size(EV_chunk, 6); end

for k = 1:K_z
    bz_cells = {};
    if has_bz && sum(spec_n_bz_one) > 0
        for i = 1:size(bz_vals_chunk, 2)
            bz_cells{end+1} = shiftdim(bz_vals_chunk(k, i), -4);
        end
    end
    e_cells = {};
    if sum(spec_n_e) > 0
        for i = 1:size(e_val, 2)
            e_cells{end+1} = shiftdim(e_val(:, i), -5);
        end
    end

    if has_cont
        ev_all_a2 = reshape(beta0 * EV_chunk(:, :, 1, :, k, :), [N_d_inner * N_a1, 1, size(EV_chunk, 4), N_e_ev]);
    end

    for i1 = 1:blk_sz:N_a1
        i2 = min(N_a1, i1 + blk_sz - 1);
        nb = i2 - i1 + 1;

        a1_cur_cells = {};
        if sum(n_a1) > 0
            for i = 1:size(a1_gridvals, 2)
                a1_cur_cells{end+1} = shiftdim(a1_gridvals(i1:i2, i), -2);
            end
        end

        F_raw = ReturnFn(d_cells{:}, a1p_cells{:}, a1_cur_cells{:}, a2_cells{:}, bz_cells{:}, e_cells{:}, ParamCell{:});
        a2_sz = size(F_raw, 4);
        F_4d  = reshape(F_raw, [N_d_inner * N_a1, nb, a2_sz, N_e_slice]);

        if has_cont
            RHS = F_4d + ev_all_a2;
            [vk, pk] = max(RHS, [], 1);
            N_a2_out = size(RHS, 3);
        else
            [vk, pk] = max(F_4d, [], 1);
            N_a2_out = a2_sz;
        end

        if N_a2_out == 1 && N_a2 > 1
            vk_b = reshape(vk, [nb, 1, N_e_slice]);
            pk_b = reshape(pk, [nb, 1, N_e_slice]);
            for a2_i = 1:N_a2
                rows = (a2_i - 1) * N_a1 + (i1:i2);
                v_out(rows, k, :) = vk_b;
                p_out(rows, k, :) = pk_b;
            end
        else
            for a2_i = 1:N_a2
                rows = (a2_i - 1) * N_a1 + (i1:i2);
                v_out(rows, k, :) = reshape(vk(1, :, a2_i, :), [nb, 1, N_e_slice]);
                p_out(rows, k, :) = reshape(pk(1, :, a2_i, :), [nb, 1, N_e_slice]);
            end
        end
    end
end


end
