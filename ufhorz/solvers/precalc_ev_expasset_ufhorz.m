% Shared verified continuation-value builder extracted verbatim from ValueFnIter_UFHorz_ExpAsset_raw.m
function DiscountedEV = precalc_ev_expasset_ufhorz(EVpre_flat, df, pi_bz, N_e_interp, ExpAsset_J, Dims, vfoptions, j, WG_j)
N_a1 = Dims.N_a1; N_a2 = Dims.N_a2; N_bothz = Dims.N_bothz; N_semiz = Dims.N_semiz;
N_d1 = Dims.N_d1; N_d2 = Dims.N_d2; N_d_inner = Dims.N_d_inner; n_a2 = Dims.n_a2;

a2p_idx_base    = ExpAsset_J.a2primeIndex;
a2p_weight_base = ExpAsset_J.a2primeProbs;

if ~isempty(EVpre_flat)
    EV_val = reshape(EVpre_flat, [N_a1*N_a2, N_bothz]);
    % Fast BLAS DGEMM expectation before linear interpolation when standard prefs & z-independent aprimeFn
    if ~Dims.ez_flag && (Dims.exp_flag == 0 || Dims.exp_flag == 1) && length(n_a2) == 1 && max(size(a2p_idx_base, 3), 1) == 1
        EVinf = (EV_val == -Inf);
        EV_clean = EV_val;
        EV_clean(EVinf) = 0;
        EV_z = EV_clean * pi_bz';
        if any(EVinf(:))
            EV_z(EVinf * (pi_bz' > 0) > 0) = -Inf;
        end
        N_d_exp  = size(a2p_idx_base, 1);
        N_a2_exp = size(a2p_idx_base, 2);
        a1_base  = repelem(vfi_gpu(1:1:N_a1)', N_d_exp, N_a2_exp);
        idx_lo   = a1_base + N_a1 * repmat(a2p_idx_base - 1, N_a1, 1);
        idx_hi   = a1_base + N_a1 * repmat(a2p_idx_base,     N_a1, 1);
        Vlower   = reshape(EV_z(idx_lo(:), :), [N_d_exp*N_a1, N_a2_exp, N_bothz]);
        Vupper   = reshape(EV_z(idx_hi(:), :), [N_d_exp*N_a1, N_a2_exp, N_bothz]);
        prob_exp = repmat(a2p_weight_base, N_a1, 1, N_bothz);
        prob_exp(Vlower == Vupper) = 0;
        EV_u = prob_exp .* Vlower + (1 - prob_exp) .* Vupper;
        EV_u(prob_exp == 0) = Vupper(prob_exp == 0);
        EV_u(prob_exp == 1) = Vlower(prob_exp == 1);
        EV_raw = reshape(EV_u, [N_d_exp, N_a1, 1, N_a2_exp, N_bothz, N_e_interp]);
    else
        EV_raw = interp_expasset_local(EV_val, a2p_idx_base, a2p_weight_base, pi_bz, N_e_interp, Dims, vfoptions);
    end
else
    EV_raw = [];
end

if ~Dims.ez_flag
    EV_coarse = EV_raw;
    N_d_exp  = size(EV_coarse, 1);
    N_a2_exp = size(EV_coarse, 4);
    if N_d_exp == 1 && N_d2 > 1;   EV_coarse = repmat(EV_coarse, [N_d2, 1, 1, 1, 1, 1]); end
    if N_a2_exp == 1 && N_a2 > 1;  EV_coarse = repmat(EV_coarse, [1, 1, 1, N_a2, 1, 1]); end
    if N_d1 > 1;                   EV_coarse = repelem(EV_coarse, N_d1, 1, 1, 1, 1, 1);  end
    DiscountedEV = df * reshape(EV_coarse, [N_d_inner, N_a1, 1, N_a2, N_bothz, N_e_interp]);
    return;
end

% Epstein-Zin + Warm-Glow
sj_j = Dims.sj(j); ezc6_j = Dims.ezc6(j); ezc8_j = Dims.ezc8(j);
if Dims.warmglow
    WG_val  = repmat(WG_j, 1, N_bothz);
    WG_raw  = interp_expasset_local(WG_val, a2p_idx_base, a2p_weight_base, pi_bz, N_e_interp, Dims, vfoptions);
end

if ~isempty(EV_raw)
    temp4 = EV_raw;
    if Dims.warmglow
        becareful = isfinite(temp4) & isfinite(WG_raw);
        temp4(becareful) = (sj_j * temp4(becareful).^ezc8_j + (1 - sj_j) * WG_raw(becareful).^ezc8_j).^ezc6_j;
        temp4((EV_raw == 0) & (WG_raw == 0)) = 0;
    else
        fin_mask = isfinite(temp4);
        temp4(fin_mask) = (sj_j * temp4(fin_mask).^ezc8_j).^ezc6_j;
        temp4(EV_raw == 0) = 0;
    end
else
    temp4 = WG_raw;
    fin_mask = isfinite(temp4) & (temp4 ~= 0);
    temp4(fin_mask) = ((1 - sj_j) * temp4(fin_mask).^ezc8_j).^ezc6_j;
    temp4(WG_raw == 0) = 0;
end

EV_coarse = Dims.ezc3 * df * temp4;
EV_coarse(isinf(temp4)) = -Inf;
N_d_exp  = size(EV_coarse, 1);
N_a2_exp = size(EV_coarse, 4);
if N_d_exp == 1 && N_d2 > 1;   EV_coarse = repmat(EV_coarse, [N_d2, 1, 1, 1, 1, 1]); end
if N_a2_exp == 1 && N_a2 > 1;  EV_coarse = repmat(EV_coarse, [1, 1, 1, N_a2, 1, 1]); end
if N_d1 > 1;                   EV_coarse = repelem(EV_coarse, N_d1, 1, 1, 1, 1, 1);  end
DiscountedEV = reshape(EV_coarse, [N_d_inner, N_a1, 1, N_a2, N_bothz, N_e_interp]);
end

function EV_coarse = interp_expasset_local(EV_val, a2p_idx_base, a2p_weight_base, pi_bz, N_e_interp, Dims, vfoptions)
N_a1 = Dims.N_a1; N_bothz = Dims.N_bothz; N_semiz = Dims.N_semiz; n_a2 = Dims.n_a2;
if length(n_a2) == 1
    N_d_exp  = size(a2p_idx_base, 1);
    N_a2_exp = size(a2p_idx_base, 2);
    N_3rd    = max(size(a2p_idx_base, 3), 1);

    if Dims.exp_flag ~= 6 && N_3rd > 1 && N_3rd ~= N_bothz
        a2p_idx_base    = reshape(repmat(reshape(a2p_idx_base, [N_d_exp, N_a2_exp, 1, N_3rd]), 1, 1, N_semiz, 1), [N_d_exp, N_a2_exp, N_bothz]);
        a2p_weight_base = reshape(repmat(reshape(a2p_weight_base, [N_d_exp, N_a2_exp, 1, N_3rd]), 1, 1, N_semiz, 1), [N_d_exp, N_a2_exp, N_bothz]);
        N_3rd = N_bothz;
    end

    a1_base  = repelem(vfi_gpu(1:1:N_a1)', N_d_exp, N_a2_exp, N_3rd);
    idx_lo   = a1_base + N_a1 * repmat(a2p_idx_base - 1, N_a1, 1, 1);
    idx_hi   = a1_base + N_a1 * repmat(a2p_idx_base,     N_a1, 1, 1);
    prob_exp = repmat(a2p_weight_base, N_a1, 1, 1, N_bothz);

    Vlower = reshape(EV_val(idx_lo(:), :), [N_d_exp*N_a1, N_a2_exp, N_3rd, N_bothz]);
    Vupper = reshape(EV_val(idx_hi(:), :), [N_d_exp*N_a1, N_a2_exp, N_3rd, N_bothz]);

    prob_exp(Vlower == Vupper) = 0;
    EV_u = prob_exp .* Vlower + (1 - prob_exp) .* Vupper;
    EV_u(prob_exp == 0) = Vupper(prob_exp == 0);
    EV_u(prob_exp == 1) = Vlower(prob_exp == 1);
else
    N_d_exp  = size(a2p_idx_base, 2);
    N_a2_exp = size(a2p_idx_base, 3);
    N_3rd    = max(size(a2p_idx_base, 4), 1);

    loIdx_1 = reshape(a2p_idx_base(1,:,:,:), [N_d_exp, N_a2_exp, N_3rd]);
    loIdx_2 = reshape(a2p_idx_base(2,:,:,:), [N_d_exp, N_a2_exp, N_3rd]);
    prob_1  = reshape(a2p_weight_base(1,:,:,:), [N_d_exp, N_a2_exp, N_3rd]);
    prob_2  = reshape(a2p_weight_base(2,:,:,:), [N_d_exp, N_a2_exp, N_3rd]);

    if Dims.exp_flag ~= 6 && N_3rd > 1 && N_3rd ~= N_bothz
        loIdx_1 = reshape(repmat(reshape(loIdx_1, [N_d_exp, N_a2_exp, 1, N_3rd]), 1, 1, N_semiz, 1), [N_d_exp, N_a2_exp, N_bothz]);
        loIdx_2 = reshape(repmat(reshape(loIdx_2, [N_d_exp, N_a2_exp, 1, N_3rd]), 1, 1, N_semiz, 1), [N_d_exp, N_a2_exp, N_bothz]);
        prob_1  = reshape(repmat(reshape(prob_1, [N_d_exp, N_a2_exp, 1, N_3rd]), 1, 1, N_semiz, 1), [N_d_exp, N_a2_exp, N_bothz]);
        prob_2  = reshape(repmat(reshape(prob_2, [N_d_exp, N_a2_exp, 1, N_3rd]), 1, 1, N_semiz, 1), [N_d_exp, N_a2_exp, N_bothz]);
        N_3rd = N_bothz;
    end

    a1_base = repelem(vfi_gpu(1:1:N_a1)', N_d_exp, N_a2_exp, N_3rd);
    n_a2_1  = n_a2(1);

    idx_ll = a1_base + N_a1 * repmat(loIdx_1 + n_a2_1*(loIdx_2-1) - 1,     N_a1, 1, 1);
    idx_hl = a1_base + N_a1 * repmat((loIdx_1+1) + n_a2_1*(loIdx_2-1) - 1, N_a1, 1, 1);
    idx_lh = a1_base + N_a1 * repmat(loIdx_1 + n_a2_1*loIdx_2 - 1,         N_a1, 1, 1);
    idx_hh = a1_base + N_a1 * repmat((loIdx_1+1) + n_a2_1*loIdx_2 - 1,     N_a1, 1, 1);

    V_ll = reshape(EV_val(idx_ll(:), :), [N_d_exp*N_a1, N_a2_exp, N_3rd, N_bothz]);
    V_hl = reshape(EV_val(idx_hl(:), :), [N_d_exp*N_a1, N_a2_exp, N_3rd, N_bothz]);
    V_lh = reshape(EV_val(idx_lh(:), :), [N_d_exp*N_a1, N_a2_exp, N_3rd, N_bothz]);
    V_hh = reshape(EV_val(idx_hh(:), :), [N_d_exp*N_a1, N_a2_exp, N_3rd, N_bothz]);

    prb1_full = repmat(prob_1, N_a1, 1, 1, N_bothz);
    prb2_full = repmat(prob_2, N_a1, 1, 1, N_bothz);

    p1_loy = prb1_full; p1_loy(V_ll == V_hl) = 0;
    c_ll = p1_loy .* V_ll; c_ll(isnan(c_ll)) = 0;
    c_hl = (1-p1_loy) .* V_hl; c_hl(isnan(c_hl)) = 0;
    EV_loy = c_ll + c_hl;

    p1_hiy = prb1_full; p1_hiy(V_lh == V_hh) = 0;
    c_lh = p1_hiy .* V_lh; c_lh(isnan(c_lh)) = 0;
    c_hh = (1-p1_hiy) .* V_hh; c_hh(isnan(c_hh)) = 0;
    EV_hiy = c_lh + c_hh;

    p2 = prb2_full; p2(EV_loy == EV_hiy) = 0;
    c_loy = p2 .* EV_loy; c_loy(isnan(c_loy)) = 0;
    c_hiy = (1-p2) .* EV_hiy; c_hiy(isnan(c_hiy)) = 0;
    EV_u = c_loy + c_hiy;
end

if Dims.exp_flag == 6
    pi_u = shiftdim(vfi_gpu(vfoptions.pi_u), -2);
    EV = squeeze(sum(EV_u .* pi_u, 3));
    EV = EV .* shiftdim(pi_bz', -2);
    EV(isnan(EV)) = 0;
    EV_coarse = squeeze(sum(EV, 3));
elseif Dims.exp_flag == 3 || Dims.exp_flag == 4
    N_z = Dims.N_z;
    EV_u = reshape(EV_u, [N_d_exp*N_a1, N_a2_exp, N_z, N_e_interp, N_bothz]);
    pi_shift = reshape(pi_bz, [1, 1, N_z, 1, N_bothz]);
    EV = EV_u .* pi_shift;
    EV(isnan(EV)) = 0;
    EV_coarse = sum(EV, 5);
elseif N_3rd > 1
    EV = EV_u .* shiftdim(pi_bz, -2);
    EV(isnan(EV)) = 0;
    EV_coarse = sum(EV, 4);
else
    EV = reshape(EV_u, [N_d_exp*N_a1, N_a2_exp, N_bothz]) .* shiftdim(pi_bz', -2);
    EV(isnan(EV)) = 0;
    EV_coarse = sum(EV, 3);
end
EV_coarse = reshape(EV_coarse, [N_d_exp, N_a1, 1, N_a2_exp, N_bothz, N_e_interp]);


end
