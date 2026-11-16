function [v_chunk, p_chunk] = ufhorz_raw_chunk_worker( ...
    ReturnFn, special_n_d, n_a, spec_n_bz_one, spec_n_e, ...
    d_val, a_grid, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a, N_e_slice)

if ischar(ReturnFn)
    ReturnFn = str2func(ReturnFn);
end

K = max(size(bz_vals_chunk, 1), 1);
v_chunk = zeros(N_a, K, N_e_slice);
p_chunk = zeros(N_a, K, N_e_slice);
has_bz  = ~isempty(bz_vals_chunk);

for k = 1:K
    if has_bz
        bz_k = bz_vals_chunk(k, :);
    else
        bz_k = [];
    end
    RM = CreateReturnFnMatrix_UDisc( ...
        ReturnFn, special_n_d, n_a, spec_n_bz_one, spec_n_e, ...
        d_val, a_grid, bz_k, e_val, ReturnFnParamsVec, 0);
    RM = reshape(RM, [N_d_inner, N_a, N_a, 1, N_e_slice]);

    if has_cont
        RHS = RM + beta0 * EV_chunk(:, :, :, k, 1);
    else
        RHS = RM;
    end

    [vk, pk] = max(reshape(RHS, [N_d_inner * N_a, N_a, N_e_slice]), [], 1);
    v_chunk(:, k, :) = reshape(vk, [N_a, 1, N_e_slice]);
    p_chunk(:, k, :) = reshape(pk, [N_a, 1, N_e_slice]);
end

end
