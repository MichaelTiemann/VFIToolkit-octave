function [v_chunk, p_chunk] = ufhorz_expasset_chunk_worker( ...
    ReturnFn, special_n_d, n_a1, n_a2, spec_n_bz_one, spec_n_e, ...
    d_val, a1_gridvals, a2_gridvals, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a1, N_a2, N_e_slice)
% UFHORZ_EXPASSET_CHUNK_WORKER Evaluates z-slices while preserving singleton-broadcasting
% across a2 when theta_c does not enter ReturnFn (avoiding 9x redundant ReturnFn evaluations!).

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

K_z = max(size(bz_vals_chunk, 1), 1);
N_a = N_a1 * N_a2;
v_chunk = zeros(N_a, K_z, N_e_slice);
p_chunk = zeros(N_a, K_z, N_e_slice);
has_bz  = ~isempty(bz_vals_chunk);

% Prepare shifted grid cells once per worker call
ParamCell = num2cell(ReturnFnParamsVec)';
GridBase = {};
if sum(special_n_d) > 0
    for i = 1:size(d_val, 2); GridBase{end+1} = d_val(:, i); end
end
if sum(n_a1) > 0
    for i = 1:size(a1_gridvals, 2); GridBase{end+1} = shiftdim(a1_gridvals(:, i), -1); end
    for i = 1:size(a1_gridvals, 2); GridBase{end+1} = shiftdim(a1_gridvals(:, i), -2); end
end
if sum(n_a2) > 0
    for i = 1:size(a2_gridvals, 2); GridBase{end+1} = shiftdim(a2_gridvals(:, i), -3); end
end

for k = 1:K_z
    GridCells = GridBase;
    if has_bz && sum(spec_n_bz_one) > 0
        for i = 1:size(bz_vals_chunk, 2)
            GridCells{end+1} = shiftdim(bz_vals_chunk(k, i), -4);
        end
    end
    if sum(spec_n_e) > 0
        for i = 1:size(e_val, 2)
            GridCells{end+1} = shiftdim(e_val(:, i), -5);
        end
    end

    % Evaluate vectorized ReturnFn directly WITHOUT repmatting unused a2!
    % When theta_c is unused at age j, F_raw has size [N_d_inner, N_a1, N_a1, 1] (122 MB instead of 1.1 GB!)
    F_raw = ReturnFn(GridCells{:}, ParamCell{:});
    a2_sz = size(F_raw, 4);

    if has_cont
        if a2_sz == 1 && N_a2 > 1
            % Broadcast [N_d_inner, N_a1, N_a1, 1] + [N_d_inner, N_a1, 1, N_a2] one a2 at a time to stay in L2/SLC cache!
            F_3d = reshape(F_raw, [N_d_inner, N_a1, N_a1, 1, N_e_slice]);
            for a2_i = 1:N_a2
                RHS_a2 = F_3d + beta0 * EV_chunk(:, :, 1, a2_i, k, :);
                [vk, pk] = max(reshape(RHS_a2, [N_d_inner * N_a1, N_a1, N_e_slice]), [], 1);
                rows = (a2_i - 1) * N_a1 + (1:N_a1);
                v_chunk(rows, k, :) = reshape(vk, [N_a1, 1, N_e_slice]);
                p_chunk(rows, k, :) = reshape(pk, [N_a1, 1, N_e_slice]);
            end
        else
            F_full = reshape(F_raw, [N_d_inner, N_a1, N_a1, N_a2, 1, N_e_slice]);
            for a2_i = 1:N_a2
                RHS_a2 = F_full(:, :, :, a2_i, 1, :) + beta0 * EV_chunk(:, :, 1, a2_i, k, :);
                [vk, pk] = max(reshape(RHS_a2, [N_d_inner * N_a1, N_a1, N_e_slice]), [], 1);
                rows = (a2_i - 1) * N_a1 + (1:N_a1);
                v_chunk(rows, k, :) = reshape(vk, [N_a1, 1, N_e_slice]);
                p_chunk(rows, k, :) = reshape(pk, [N_a1, 1, N_e_slice]);
            end
        end
    else
        % Terminal period (no continuation value)
        if a2_sz == 1 && N_a2 > 1
            [vk, pk] = max(reshape(F_raw, [N_d_inner * N_a1, N_a1, N_e_slice]), [], 1);
            v_chunk(:, k, :) = repmat(reshape(vk, [N_a1, 1, N_e_slice]), [N_a2, 1, 1]);
            p_chunk(:, k, :) = repmat(reshape(pk, [N_a1, 1, N_e_slice]), [N_a2, 1, 1]);
        else
            RHS = reshape(F_raw, [N_d_inner * N_a1, N_a, N_e_slice]);
            [vk, pk] = max(RHS, [], 1);
            v_chunk(:, k, :) = reshape(vk, [N_a, 1, N_e_slice]);
            p_chunk(:, k, :) = reshape(pk, [N_a, 1, N_e_slice]);
        end
    end
end

end
