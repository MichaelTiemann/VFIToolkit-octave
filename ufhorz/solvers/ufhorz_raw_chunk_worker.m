function [v_chunk, p_chunk] = ufhorz_raw_chunk_worker( ...
    ReturnFn, special_n_d, n_a, spec_n_bz_one, spec_n_e, ...
    d_val, a_grid, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a, N_e_slice)
% UFHORZ_RAW_CHUNK_WORKER Cache-tiled map-reduce kernel for 4D Compact UFHorz models.

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

K_z = max(size(bz_vals_chunk, 1), 1);
v_chunk = zeros(N_a, K_z, N_e_slice);
p_chunk = zeros(N_a, K_z, N_e_slice);
has_bz  = ~isempty(bz_vals_chunk);

a_gridvals = CreateGridvals(n_a, a_grid(:), 1);
ParamCell  = num2cell(ReturnFnParamsVec)';

d_cells = {};
if sum(special_n_d) > 0
    for i = 1:size(d_val, 2); d_cells{end+1} = d_val(:, i); end
end
ap_cells = {};
for i = 1:size(a_gridvals, 2); ap_cells{end+1} = shiftdim(a_gridvals(:, i), -1); end

blk_sz = 61;
n_blks = ceil(N_a / blk_sz);

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
        ev_vec = reshape(beta0 * EV_chunk(:, :, 1, k, 1), [N_d_inner * N_a, 1, N_e_slice]);
    end

    for b = 1:n_blks
        i1 = (b - 1) * blk_sz + 1;
        i2 = min(N_a, b * blk_sz);
        nb = i2 - i1 + 1;

        a_cur_cells = {};
        for i = 1:size(a_gridvals, 2)
            a_cur_cells{end+1} = shiftdim(a_gridvals(i1:i2, i), -2);
        end

        F_raw = ReturnFn(d_cells{:}, ap_cells{:}, a_cur_cells{:}, bz_cells{:}, e_cells{:}, ParamCell{:});
        RHS = reshape(F_raw, [N_d_inner * N_a, nb, N_e_slice]);
        if has_cont
            RHS = RHS + ev_vec;
        end
        [vk, pk] = max(RHS, [], 1);
        v_chunk(i1:i2, k, :) = reshape(vk, [nb, 1, N_e_slice]);
        p_chunk(i1:i2, k, :) = reshape(pk, [nb, 1, N_e_slice]);
    end
end

end
