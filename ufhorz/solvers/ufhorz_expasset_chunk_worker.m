function [v_chunk, p_chunk] = ufhorz_expasset_chunk_worker( ...
    ReturnFn, special_n_d, n_a1, n_a2, spec_n_bz_one, spec_n_e, ...
    d_val, a1_gridvals, a2_vals_chunk, bz_vals_chunk, e_val, ...
    ReturnFnParamsVec, has_cont, beta0, EV_chunk, N_d_inner, N_a1, N_e_slice)
% UFHORZ_EXPASSET_CHUNK_WORKER Fused L2/SLC-cache-sized map-reduce kernel over (a2, z) pairs.
% Evaluates ReturnFn + beta0 * DiscountedEV + max() one (a2, z) pair at a time (~122 MB buffer)
% and returns only the compact [N_a1, K_pairs, N_e_slice] value & policy arrays!

K = size(a2_vals_chunk, 1);
v_chunk = zeros(N_a1, K, N_e_slice);
p_chunk = zeros(N_a1, K, N_e_slice);

has_bz = ~isempty(bz_vals_chunk);

for k = 1:K
    a2_k = a2_vals_chunk(k, :);
    if has_bz
        bz_k = bz_vals_chunk(k, :);
    else
        bz_k = [];
    end

    RM = CreateReturnFnMatrix_ExpAsset_UDisc( ...
        ReturnFn, special_n_d, n_a1, ones(1, length(n_a2)), spec_n_bz_one, spec_n_e, ...
        d_val, a1_gridvals, a1_gridvals, a2_k, bz_k, e_val, ReturnFnParamsVec, 1);
    RM = reshape(RM, [N_d_inner, N_a1, N_a1, 1, 1, N_e_slice]);

    if has_cont
        RHS = RM + beta0 * EV_chunk(:, :, 1, k, :);
    else
        RHS = RM;
    end

    [vk, pk] = max(reshape(RHS, [N_d_inner * N_a1, N_a1, N_e_slice]), [], 1);
    v_chunk(:, k, :) = reshape(vk, [N_a1, 1, N_e_slice]);
    p_chunk(:, k, :) = reshape(pk, [N_a1, 1, N_e_slice]);
end

end
