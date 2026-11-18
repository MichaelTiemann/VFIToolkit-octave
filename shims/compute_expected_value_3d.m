function EV = compute_expected_value_3d(V_next, pi_z, a2primeIndex, a2primeProbs, N_d2, N_a1, N_a2, N_z)
% 1. Contract over zprime FIRST on the compact [N_a, N_z] state space (208 KB in L2 cache!)
if any(isinf(V_next(:)))
    % Exact preservation of 0 * (-Inf) == 0 transition probability semantics
    EV_state = zeros(size(V_next), class(V_next));
    for z_c = 1:N_z
        pz = pi_z(z_c, :);
        nz = (pz ~= 0);
        if any(nz)
            EV_state(:, z_c) = V_next(:, nz) * pz(nz).';
        end
    end
else
    % Single BLAS DGEMM on [N_a, N_z] x [N_z, N_z] -- microsecond execution!
    EV_state = V_next * pi_z.';
end

% 2. Gather [N_d2*N_a1, N_a2, N_z] in 3D (NO 4th zprime dimension needed!)
% Linear index into EV_state([N_a1*N_a2, N_z]): a1' + N_a1*(a2'_idx - 1) + N_a1*N_a2*(z - 1)
z_offset  = reshape((0:N_z-1) * (N_a1 * N_a2), [1, 1, N_z]);
base_low  = N_a1 * (a2primeIndex - 1) + z_offset; % [N_d2, N_a2, N_z]
base_high = base_low + N_a1;                      % [N_d2, N_a2, N_z]

% Expand across a1' = 1:N_a1: [N_d2, N_a1, N_a2, N_z] -> [N_d2*N_a1, N_a2, N_z]
a1_vec   = reshape(1:N_a1, [1, N_a1, 1, 1]);
idx_low  = reshape(bsxfun(@plus, reshape(base_low,  [N_d2, 1, N_a2, N_z]), a1_vec), [N_d2 * N_a1, N_a2, N_z]);
idx_high = reshape(bsxfun(@plus, reshape(base_high, [N_d2, 1, N_a2, N_z]), a1_vec), [N_d2 * N_a1, N_a2, N_z]);

Vlower = EV_state(idx_low);
Vupper = EV_state(idx_high);

probs_4d = bsxfun(@times, reshape(a2primeProbs, [N_d2, 1, N_a2, N_z]), ones(1, N_a1, 1, 1));
probs_3d = reshape(probs_4d, [N_d2 * N_a1, N_a2, N_z]);
probs_3d(Vlower == Vupper) = 0;

EV = probs_3d .* Vlower + (1 - probs_3d) .* Vupper;


end
