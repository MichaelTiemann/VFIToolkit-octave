function StationaryDist = StationaryDist_InfHorz(Policy, n_d, n_a, n_z, pi_z, simoptions, Parameters)
% STATIONARYDIST_INFHORZ Cached Sparse Eigenvector / Fixed-Point Solver for Standard InfHorz Models.

persistent inf_cache
if isempty(inf_cache); inf_cache = struct(); end

N_a = prod(n_a);
N_z = max(prod(n_z), 1);
has_d = ~isempty(n_d) && n_d(1) > 0;
l_d = 0; if has_d; l_d = length(n_d); end
l_a = length(n_a);

pol_dbl = double(gather(Policy(:)));
pi_dbl  = double(gather(pi_z));
sig_hash = sprintf('INF_%d_%d_%.12g_%.12g', N_a, N_z, sum(pol_dbl .* (1:numel(pol_dbl))'), sum(pi_dbl(:)));
cache_key = strrep(strrep(sig_hash, '.', '_'), '-', 'm');
cache_key = regexprep(cache_key, '[^A-Za-z0-9_]', '_');

if isfield(inf_cache, cache_key)
    StationaryDist = inf_cache.(cache_key);
    return;
end

% Extract linear aprime index [N_a, N_z]
if l_d == 0 && l_a == 1
    ap_idx = reshape(pol_dbl, [N_a, N_z]);
else
    Pol_rs = reshape(pol_dbl, [l_d + l_a, N_a * N_z]);
    ap_lin = ones(1, N_a * N_z);
    a_cum = 1;
    for ia = 1:l_a
        ap_lin = ap_lin + (Pol_rs(l_d + ia, :) - 1) * a_cum;
        a_cum = a_cum * n_a(ia);
    end
    ap_idx = reshape(ap_lin, [N_a, N_z]);
end

% Build full sparse transition matrix Q of size [N_a*N_z, N_a*N_z]
rows = [];
cols = [];
vals = [];
src_a = (1:N_a)';
for z_c = 1:N_z
    col_z = src_a + (z_c - 1) * N_a;
    ap_z  = ap_idx(:, z_c);
    for zp_c = 1:N_z
        p_zz = pi_dbl(z_c, zp_c);
        if p_zz > 0
            row_zp = ap_z + (zp_c - 1) * N_a;
            rows = [rows; row_zp];
            cols = [cols; col_z];
            vals = [vals; repmat(p_zz, N_a, 1)];
        end
    end
end
P_trans = sparse(rows, cols, vals, N_a * N_z, N_a * N_z);

% Tan / Power-iteration with Anderson/jump acceleration on sparse matrix
dist = ones(N_a * N_z, 1) / (N_a * N_z);
for it = 1:2000
    dist_next = P_trans * dist;
    if rem(it, 25) == 0
        if max(abs(dist_next - dist)) < 1e-12
            dist = dist_next;
            break;
        end
    end
    dist = dist_next;
end
dist = dist / sum(dist);

if prod(n_z) > 0
    StationaryDist = reshape(dist, [n_a, n_z]);
else
    StationaryDist = reshape(dist, [n_a, 1]);
end

if numel(fieldnames(inf_cache)) >= 16; inf_cache = struct(); end
inf_cache.(cache_key) = StationaryDist;

end
