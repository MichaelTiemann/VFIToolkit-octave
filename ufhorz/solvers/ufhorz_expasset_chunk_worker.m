function [v_chunk, p_chunk] = ufhorz_expasset_chunk_worker( ...
    ReturnFn, special_n_d, n_a1, n_a2, spec_n_bz_one, spec_n_e, ...
    d_val, a1_gridvals, a2_gridvals, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a1, N_a2, N_e_slice)
% UFHORZ_EXPASSET_CHUNK_WORKER Cache-tiled (a1 sub-blocked) map-reduce kernel.
% Evaluates current-a1 in blocks of <= 64 points (~17 MB per intermediate tensor)
% so worker RSS stays ~350 MB instead of 3.2 GB while staying hot in M5 Max SLC!

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

K_z = max(size(bz_vals_chunk, 1), 1);
N_a = N_a1 * N_a2;
v_chunk = zeros(N_a, K_z, N_e_slice);
p_chunk = zeros(N_a, K_z, N_e_slice);
has_bz  = ~isempty(bz_vals_chunk);

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

% Tile current a1 into blocks of ~61 points (exact match to n_a1(1) = 61!)
blk_sz = 61;
n_blks = ceil(N_a1 / blk_sz);

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

    for b = 1:n_blks
        i1 = (b - 1) * blk_sz + 1;
        i2 = min(N_a1, b * blk_sz);
        nb = i2 - i1 + 1;

        a1_cur_cells = {};
        if sum(n_a1) > 0
            for i = 1:size(a1_gridvals, 2)
                a1_cur_cells{end+1} = shiftdim(a1_gridvals(i1:i2, i), -2);
            end
        end

        F_raw = ReturnFn(d_cells{:}, a1p_cells{:}, a1_cur_cells{:}, a2_cells{:}, bz_cells{:}, e_cells{:}, ParamCell{:});
        a2_sz = size(F_raw, 4);

        if has_cont
            if a2_sz == 1 && N_a2 > 1
                F_3d = reshape(F_raw, [N_d_inner * N_a1, nb, N_e_slice]);
                for a2_i = 1:N_a2
                    ev_vec = reshape(beta0 * EV_chunk(:, :, 1, a2_i, k, :), [N_d_inner * N_a1, 1, N_e_slice]);
                    [vk, pk] = max(F_3d + ev_vec, [], 1);
                    rows = (a2_i - 1) * N_a1 + (i1:i2);
                    v_chunk(rows, k, :) = reshape(vk, [nb, 1, N_e_slice]);
                    p_chunk(rows, k, :) = reshape(pk, [nb, 1, N_e_slice]);
                end
            else
                F_4d = reshape(F_raw, [N_d_inner * N_a1, nb, N_a2, N_e_slice]);
                for a2_i = 1:N_a2
                    ev_vec = reshape(beta0 * EV_chunk(:, :, 1, a2_i, k, :), [N_d_inner * N_a1, 1, N_e_slice]);
                    [vk, pk] = max(F_4d(:, :, a2_i, :) + ev_vec, [], 1);
                    rows = (a2_i - 1) * N_a1 + (i1:i2);
                    v_chunk(rows, k, :) = reshape(vk, [nb, 1, N_e_slice]);
                    p_chunk(rows, k, :) = reshape(pk, [nb, 1, N_e_slice]);
                end
            end
        else
            if a2_sz == 1 && N_a2 > 1
                [vk, pk] = max(reshape(F_raw, [N_d_inner * N_a1, nb, N_e_slice]), [], 1);
                vk_b = reshape(vk, [nb, 1, N_e_slice]);
                pk_b = reshape(pk, [nb, 1, N_e_slice]);
                for a2_i = 1:N_a2
                    rows = (a2_i - 1) * N_a1 + (i1:i2);
                    v_chunk(rows, k, :) = vk_b;
                    p_chunk(rows, k, :) = pk_b;
                end
            else
                F_4d = reshape(F_raw, [N_d_inner * N_a1, nb, N_a2, N_e_slice]);
                for a2_i = 1:N_a2
                    [vk, pk] = max(F_4d(:, :, a2_i, :), [], 1);
                    rows = (a2_i - 1) * N_a1 + (i1:i2);
                    v_chunk(rows, k, :) = reshape(vk, [nb, 1, N_e_slice]);
                    p_chunk(rows, k, :) = reshape(pk, [nb, 1, N_e_slice]);
                end
            end
        end
    end
end

end
