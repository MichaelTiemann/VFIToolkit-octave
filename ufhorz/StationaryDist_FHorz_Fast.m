function StationaryDist = StationaryDist_FHorz_Fast(jequaloneDist, AgeWeightParamNames, Policy, n_d, n_a, n_z, N_j, pi_z, Parameters, simoptions)
% STATIONARYDIST_FHORZ_FAST Vectorized Tan-Improvement 4D/5D Forward Sweep with Policy-Operator Caching.
% Recomputes experience-asset aprimeFn interpolation ONLY when (Policy, pi_z, Parameters) change;
% across fixed-policy intergenerational loops (e.g. ig_iter = 1..12), sweeps all J ages in ~2 ms!

persistent op_cache
if isempty(op_cache)
    op_cache = struct();
end

if exist('simoptions', 'var') == 0 || isempty(simoptions)
    simoptions = struct();
end
has_exp = isfield(simoptions, 'experienceasset') && simoptions.experienceasset == 1;

N_a = prod(n_a);
N_z = max(prod(n_z), 1);
has_d = ~isempty(n_d) && n_d(1) > 0;
l_d = 0; if has_d; l_d = length(n_d); end

% Build fast deterministic cache signature over Policy + pi_z + key aprimeFn scalars
pol_dbl = double(Policy(:));
n_pol = numel(pol_dbl);
sample_idx = round(linspace(1, n_pol, min(n_pol, 257)));
sig_vec = [N_a; N_z; N_j; double(has_exp); sum(pol_dbl); pol_dbl(sample_idx); double(pi_z(:))];
if has_exp && isfield(Parameters, 'Q_reg') && isnumeric(Parameters.Q_reg)
    sig_vec = [sig_vec; Parameters.Q_reg(:)];
end
if has_exp && isfield(Parameters, 'G_ece_stage1') && isnumeric(Parameters.G_ece_stage1)
    sig_vec = [sig_vec; Parameters.G_ece_stage1(:); Parameters.K_whanau(:)];
end
sig_hash = sprintf('K_%d_%d_%d_%.12g_%.12g', N_a, N_z, N_j, sum(sig_vec .* (1:numel(sig_vec))'), sum(pol_dbl));
cache_key = matlab.lang.makeValidName(strrep(strrep(sig_hash, '.', '_'), '-', 'm'));

if ~isfield(op_cache, cache_key)
    % Precompute age-by-age transition operators once for this Policy!
    ops = cell(1, N_j - 1);

    if ~has_exp
        % Standard 4D endogenous states: Policy rows (l_d+1 .. l_d+l_a) give exact next-state index
        l_a = length(n_a);
        Pol_rs = reshape(Policy, [size(Policy, 1), N_a * N_z, N_j]);
        for j = 1:(N_j - 1)
            ap_lin = ones(1, N_a * N_z);
            a_cum = 1;
            for ia = 1:l_a
                ap_lin = ap_lin + (double(Pol_rs(l_d + ia, :, j)) - 1) * a_cum;
                a_cum = a_cum * n_a(ia);
            end
            ops{j} = struct('is_exp', false, 'ap_idx', reshape(ap_lin, [N_a, N_z]));
        end
    else
        % Experience-Asset endogenous state split: n_a = [n_a1, n_a2], n_d = [n_d1, n_d2]
        n_a1 = n_a(1:end-1); N_a1 = prod(n_a1); l_a1 = length(n_a1);
        n_a2 = n_a(end);     N_a2 = n_a2;
        n_d2 = n_d(end);     N_d2 = n_d2;
        d2_grid = double(simoptions.d_grid(sum(n_d(1:end-1))+1 : end));
        a2_grid = double(simoptions.a_grid(sum(n_a1)+1 : end));

        temp_args = getAnonymousFnInputNames(simoptions.aprimeFn);
        if length(temp_args) > 2
            aprimeParamNames = temp_args(3:end);
        else
            aprimeParamNames = {};
        end

        Pol_rs = reshape(Policy, [size(Policy, 1), N_a, N_z, N_j]);
        a2_state_idx = repelem((1:N_a2)', N_a1, 1); % [N_a, 1] mapping each state to its current a2 index

        for j = 1:(N_j - 1)
            aprimeParamsVec = CreateVectorFromParams(Parameters, aprimeParamNames, j);
            [a2p_idx_mat, a2p_prob_mat] = CreateExperienceAssetFnMatrix_UDisc( ...
                simoptions.aprimeFn, n_d2, n_a2, d2_grid(:), a2_grid(:), aprimeParamsVec, 2);
            % a2p_idx_mat, a2p_prob_mat are [N_d2, N_a2]

            d2_pol = double(reshape(Pol_rs(l_d, :, :, j), [N_a, N_z])); % [N_a, N_z] in 1..N_d2
            a1p_lin = ones(N_a, N_z);
            a_cum = 1;
            for ia = 1:l_a1
                a1p_lin = a1p_lin + (double(reshape(Pol_rs(l_d + ia, :, :, j), [N_a, N_z])) - 1) * a_cum;
                a_cum = a_cum * n_a1(ia);
            end

            da2_lin = d2_pol + N_d2 * (a2_state_idx - 1); % [N_a, N_z] linear index into [N_d2, N_a2]
            a2_lo   = a2p_idx_mat(da2_lin);
            p_lo    = a2p_prob_mat(da2_lin);

            idx_lo  = a1p_lin + N_a1 * (a2_lo - 1);
            idx_hi  = a1p_lin + N_a1 * a2_lo;

            % Build sparse [N_a x N_a] policy transition matrix per z_c (only N_z = 5 or 7 small sparse matrices!)
            S_z = cell(1, N_z);
            src_cols = (1:N_a)';
            for z_c = 1:N_z
                S_z{z_c} = sparse( ...
                    [idx_lo(:, z_c); idx_hi(:, z_c)], ...
                    [src_cols;       src_cols], ...
                    [p_lo(:, z_c);   1.0 - p_lo(:, z_c)], ...
                    N_a, N_a);
            end
            ops{j} = struct('is_exp', true, 'S_z', {S_z});
        end
    end

    % Bound cache size to 16 entries so counterfactual sweeps never leak RAM
    if numel(fieldnames(op_cache)) >= 16
        op_cache = struct();
    end
    op_cache.(cache_key) = ops;
else
    ops = op_cache.(cache_key);
end

% --- Two-Step Tan (2020) Forward Age Sweep ---
Dist = zeros(N_a, N_z, N_j);
Dist(:, :, 1) = reshape(double(gather(jequaloneDist)), [N_a, N_z]);
pi_z_dbl = double(gather(pi_z));

for j = 1:(N_j - 1)
    op = ops{j};
    D_j = Dist(:, :, j);
    D_after_a = zeros(N_a, N_z);

    if op.is_exp
        for z_c = 1:N_z
            D_after_a(:, z_c) = op.S_z{z_c} * D_j(:, z_c);
        end
    else
        for z_c = 1:N_z
            D_after_a(:, z_c) = accumarray(op.ap_idx(:, z_c), D_j(:, z_c), [N_a, 1]);
        end
    end

    % Step 2 of Tan Improvement: exogenous shock transition across z -> z'
    if ndims(pi_z_dbl) >= 3
        Dist(:, :, j + 1) = D_after_a * pi_z_dbl(:, :, j);
    else
        Dist(:, :, j + 1) = D_after_a * pi_z_dbl;
    end
end

% Apply age weights mewj
mewj = double(gather(Parameters.(AgeWeightParamNames{1})));
Dist = Dist .* reshape(mewj(:), [1, 1, N_j]);

if prod(n_z) > 0
    StationaryDist = reshape(Dist, [n_a, n_z, N_j]);
else
    StationaryDist = reshape(Dist, [n_a, N_j]);
end

end
