function [V, Policy] = ValueFnIter_MixHorz_PType(n_d, n_a, n_z, N_j, Names_i, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, vfoptions)
% VALUEFNITER_MIXHORZ_PTYPE Octave Parallel Permanent-Type Dispatcher.
% Dispatches all permanent types concurrently across persistent workers when ncores >= N_fhorz!

if iscell(Names_i)
    N_i = numel(Names_i);
else
    N_i = Names_i;
    Names_i = arrayfun(@(k) sprintf('ptype%03d', k), 1:N_i, 'UniformOutput', false);
end

if exist('vfoptions', 'var') == 0 || isempty(vfoptions)
    vfoptions = struct();
end

pool_st = struct('active', false, 'ncores', 0, 'ram_dir', '');
if exist('OCTAVE_VERSION', 'builtin') ~= 0 && exist('vfi_pool', 'file') ~= 0
    pool_st = vfi_pool('status');
end

% Note: If ncores >= 8 and we have 4 FHorz HH regions, running all 4 HH regions concurrently on 4 workers
% uses only 4 cores unless we either:
%   (A) Solve each HH region sequentially using n_z workers (5 or 7 cores), OR
%   (B) Run ALL 4 HH regions concurrently AND split each region's z-slices across sub-workers!
% Even simpler & 100% core-saturating: launch all 4 HH regions concurrently on workers 1..4 ONLY when ncores == 4,
% OR let a 2-level pool dispatch (4 regions x n_z = 20 or 28 tasks) saturate ALL 16 workers!

V = struct();
Policy = struct();

% First solve all ultra-fast InfHorz types locally (< 0.05s total)
fhorz_list = {};
for ii = 1:N_i
    nm = Names_i{ii};
    nj_i = extract_ptype_struct(N_j, nm, ii, N_i);
    if isinf(nj_i)
        nd_i   = extract_ptype_struct(n_d, nm, ii, N_i);
        na_i   = extract_ptype_struct(n_a, nm, ii, N_i);
        nz_i   = extract_ptype_struct(n_z, nm, ii, N_i);
        dg_i   = extract_ptype_struct(d_grid, nm, ii, N_i);
        ag_i   = extract_ptype_struct(a_grid, nm, ii, N_i);
        zg_i   = extract_ptype_struct(z_grid, nm, ii, N_i);
        piz_i  = extract_ptype_struct(pi_z, nm, ii, N_i);
        rf_i   = ReturnFn.(nm);
        par_i  = extract_ptype_struct(Parameters, nm, ii, N_i);
        disc_i = extract_ptype_struct(DiscountFactorParamNames, nm, ii, N_i);
        vfo_i  = extract_ptype_struct(vfoptions, nm, ii, N_i);
        [V.(nm), Policy.(nm)] = ValueFnIter_InfHorz(nd_i, na_i, nz_i, dg_i, ag_i, zg_i, piz_i, rf_i, par_i, disc_i, [], vfo_i);
    else
        fhorz_list{end+1} = ii;
    end
end

n_fh = numel(fhorz_list);
if n_fh == 0
    return;
end

% Check if all FHorz types are ExperienceAsset models with identical N_j so we can fuse their (region x z) slices across all 16 workers!
can_batch_fhorz = pool_st.active && pool_st.ncores > n_fh && n_fh > 1;
if can_batch_fhorz
    [V_fh, Pol_fh, ok] = batch_solve_fhorz_ptypes(fhorz_list, Names_i, N_i, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, vfoptions, pool_st);
    if ok
        for idx = 1:n_fh
            nm = Names_i{fhorz_list{idx}};
            V.(nm)      = V_fh{idx};
            Policy.(nm) = Pol_fh{idx};
        end
        return;
    end
end

% Fallback: solve each FHorz PType sequentially (each using z-slice workers internally)
for idx = 1:n_fh
    ii     = fhorz_list{idx};
    nm     = Names_i{ii};
    nj_i   = extract_ptype_struct(N_j, nm, ii, N_i);
    nd_i   = extract_ptype_struct(n_d, nm, ii, N_i);
    na_i   = extract_ptype_struct(n_a, nm, ii, N_i);
    nz_i   = extract_ptype_struct(n_z, nm, ii, N_i);
    dg_i   = extract_ptype_struct(d_grid, nm, ii, N_i);
    ag_i   = extract_ptype_struct(a_grid, nm, ii, N_i);
    zg_i   = extract_ptype_struct(z_grid, nm, ii, N_i);
    piz_i  = extract_ptype_struct(pi_z, nm, ii, N_i);
    rf_i   = ReturnFn.(nm);
    par_i  = extract_ptype_struct(Parameters, nm, ii, N_i);
    disc_i = extract_ptype_struct(DiscountFactorParamNames, nm, ii, N_i);
    vfo_i  = extract_ptype_struct(vfoptions, nm, ii, N_i);
    [V.(nm), Policy.(nm)] = ValueFnIter_Case1_FHorz(nd_i, na_i, nz_i, nj_i, dg_i, ag_i, zg_i, piz_i, rf_i, par_i, disc_i, [], vfo_i);
end

end

function [V_out, Pol_out, ok] = batch_solve_fhorz_ptypes(fhorz_list, Names_i, N_i, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, vfoptions, pool_st)
% Fuses all R finite-horizon regions x N_z shock points (e.g. 4 x 5 = 20 or 4 x 7 = 28 tasks)
% into a single age-by-age dispatch across all 16 persistent workers!
ok = false;
R = numel(fhorz_list);
V_out = cell(1, R);
Pol_out = cell(1, R);

st = cell(1, R);
N_j_common = -1;

for r = 1:R
    ii   = fhorz_list{r};
    nm   = Names_i{ii};
    nj_r = extract_ptype_struct(N_j, nm, ii, N_i);
    vfo  = Default_VFOptions_FHorz(extract_ptype_struct(vfoptions, nm, ii, N_i));

    if r == 1; N_j_common = nj_r; end
    if nj_r ~= N_j_common || (vfo.experienceasset ~= 1 && vfo.experienceasset ~= 0) || vfo.experienceassetu ~= 0 || vfo.experienceassete ~= 0 ...
            || vfo.experienceassetz ~= 0 || vfo.experienceassetze ~= 0 || vfo.experienceassetsemiz ~= 0 ...
            || vfo.riskyasset ~= 0 || vfo.residualasset ~= 0 || vfo.dynasty ~= 0 ...
            || vfo.divideandconquer ~= 0 || vfo.gridinterplayer ~= 0 ...
            || ~strcmp(vfo.exoticpreferences, 'None') || prod(vfo.n_e) > 0 || prod(vfo.n_semiz) > 0
        return; % Fall back cleanly if heterogeneous horizons or non-ExpAsset
    end

    nd_r  = extract_ptype_struct(n_d, nm, ii, N_i);
    na_r  = extract_ptype_struct(n_a, nm, ii, N_i);
    nz_r  = extract_ptype_struct(n_z, nm, ii, N_i);
    dg_r  = gpuArray(extract_ptype_struct(d_grid, nm, ii, N_i));
    ag_r  = gpuArray(extract_ptype_struct(a_grid, nm, ii, N_i));
    zg_r  = gpuArray(extract_ptype_struct(z_grid, nm, ii, N_i));
    piz_r = gpuArray(extract_ptype_struct(pi_z, nm, ii, N_i));
    rf_r  = ReturnFn.(nm);
    par_r = extract_ptype_struct(Parameters, nm, ii, N_i);
    dsc_r = extract_ptype_struct(DiscountFactorParamNames, nm, ii, N_i);

    d_gv  = CreateGridvals(nd_r, dg_r, 1);
    [z_gv_J, piz_J, vfo] = ExogShockSetup_FHorz(nz_r, zg_r, piz_r, nj_r, par_r, vfo, 3, 0);
    rf_pnames = ReturnFnParamNamesFn(rf_r, nd_r, na_r, nz_r, nj_r, vfo, par_r);
    vfo = SetupNonStandardEndoStates_FHorz(nd_r, na_r, dg_r, ag_r, vfo);
    [Dims, Grids] = Setup_UFHorz(nd_r, na_r, nz_r, nj_r, d_gv, z_gv_J, vfo, par_r);

    if Dims.N_d_outer > 1; return; end
    if r == 1
        is_exp_mode = (vfo.experienceasset == 1);
    elseif (vfo.experienceasset == 1) ~= is_exp_mode
        return;
    end

    s = struct();
    s.nd = nd_r; s.na = na_r; s.nz = nz_r; s.ag = ag_r; s.rf = rf_r;
    s.par = par_r; s.dsc = dsc_r; s.rf_pnames = rf_pnames; s.vfo = vfo;
    s.Dims = Dims; s.Grids = Grids; s.piz_J = piz_J;
    s.VKron  = zeros(Dims.N_a, Dims.N_bothz, 1, nj_r);
    s.PKron  = zeros(1, Dims.N_a, Dims.N_bothz, 1, nj_r);
    st{r} = s;
end

% Build flat task map of all (r, z_i) pairs across the R regions (e.g. 4 x 5 = 20 or 4 x 7 = 28!)
task_r = [];
task_z = [];
for r = 1:R
    nz_tot = st{r}.Dims.N_bothz;
    task_r = [task_r; repmat(r, nz_tot, 1)];
    task_z = [task_z; (1:nz_tot)'];
end
N_tasks = numel(task_r);
n_work  = min(pool_st.ncores, N_tasks);
edges   = round(linspace(0, N_tasks, n_work + 1));

% Backward induction across j = N_j .. 1 dispatching all regions x z simultaneously across all 16 cores!
for j = N_j_common:-1:1
    has_cont = (j < N_j_common);
    reg_EV = cell(1, R);
    reg_rfvec = cell(1, R);

    for r = 1:R
        s = st{r};
        Dims = s.Dims; Grids = s.Grids; vfo = s.vfo;
        reg_rfvec{r} = CreateVectorFromParams(s.par, s.rf_pnames, j);
        df = prod(CreateVectorFromParams(s.par, s.dsc, j));

        if has_cont
            if is_exp_mode
                EVpre_flat = reshape(s.VKron(:, :, 1, j+1), [Dims.N_a1 * Dims.N_a2, Dims.N_bothz]);
                ap_vec = CreateVectorFromParams(s.par, Dims.aprimeFnParamNames, j);
                [a2pIdx, a2pPrb] = CreateExperienceAssetFnMatrix_UDisc(vfo.aprimeFn, Dims.n_d2, Dims.n_a2, Grids.d2_gridvals, vfo.a2_grid, ap_vec, 2);

                N_d_exp  = size(a2pIdx, 1);
                N_a2_exp = size(a2pIdx, 2);
                a1_base  = repelem((1:Dims.N_a1)', N_d_exp, N_a2_exp);
                idx_lo   = a1_base + Dims.N_a1 * repmat(a2pIdx - 1, Dims.N_a1, 1);
                idx_hi   = a1_base + Dims.N_a1 * repmat(a2pIdx,     Dims.N_a1, 1);
                prob_exp = repmat(a2pPrb, Dims.N_a1, 1, Dims.N_bothz);

                Vlo = reshape(EVpre_flat(idx_lo(:), :), [N_d_exp * Dims.N_a1, N_a2_exp, Dims.N_bothz]);
                Vhi = reshape(EVpre_flat(idx_hi(:), :), [N_d_exp * Dims.N_a1, N_a2_exp, Dims.N_bothz]);
                prob_exp(Vlo == Vhi) = 0;
                EV_u = prob_exp .* Vlo + (1 - prob_exp) .* Vhi;
                EV_u(prob_exp == 0) = Vhi(prob_exp == 0);
                EV_u(prob_exp == 1) = Vlo(prob_exp == 1);

                EV = EV_u .* shiftdim(s.piz_J(:, :, j)', -2);
                EV(isnan(EV)) = 0;
                EV_c = reshape(sum(EV, 3), [N_d_exp, Dims.N_a1, 1, N_a2_exp, Dims.N_bothz, 1]);
                if Dims.N_d1 > 1
                    EV_c = repelem(EV_c, Dims.N_d1, 1, 1, 1, 1, 1);
                end
                reg_EV{r} = df * reshape(EV_c, [Dims.N_d_inner, Dims.N_a1, 1, Dims.N_a2, Dims.N_bothz, 1]);
            else
                EVpre_flat = reshape(s.VKron(:, :, 1, j+1), [Dims.N_a, Dims.N_bothz]);
                EVinf = (EVpre_flat == -Inf);
                EV_val = EVpre_flat;
                EV_val(EVinf) = -1e250;
                EV_val = EV_val * s.piz_J(:, :, j)';
                if any(EVinf(:))
                    EV_val((double(EVinf) * double(s.piz_J(:, :, j)' > 0)) > 0) = -Inf;
                end
                EV_c = reshape(EV_val, [1, Dims.N_a, 1, Dims.N_bothz, 1]);
                if Dims.N_d_inner > 1
                    EV_c = repelem(EV_c, Dims.N_d_inner, 1, 1, 1, 1);
                end
                reg_EV{r} = df * EV_c;
            end
        end
    end

    % Package multi-region sub-batches across all 16 workers
    w_args = cell(1, n_work);
    for w = 1:n_work
        t_rng = (edges(w) + 1):edges(w + 1);
        sub_jobs = cell(1, numel(t_rng));
        for k = 1:numel(t_rng)
            ti = t_rng(k);
            rr = task_r(ti);
            zz = task_z(ti);
            s  = st{rr};
            Dims = s.Dims; Grids = s.Grids;
            bz_k = Grids.bothz_gridvals_J(zz, :, j);
            if is_exp_mode
                if has_cont; ev_k = reg_EV{rr}(:, :, 1, :, zz, 1); else; ev_k = []; end
                sub_jobs{k} = {resolve_fn_name(s.rf), Dims.special_n_d, Dims.n_a1, Dims.n_a2, ...
                    ones(1, length(Dims.n_bothz)), 0, Grids.d12_gridvals, Grids.a1_gridvals, ...
                    Grids.a2_gridvals, bz_k, [], reg_rfvec{rr}, has_cont, 1.0, ev_k, ...
                    Dims.N_d_inner, Dims.N_a1, Dims.N_a2, 1};
            else
                if has_cont; ev_k = reg_EV{rr}(:, :, 1, zz, 1); else; ev_k = []; end
                sub_jobs{k} = {resolve_fn_name(s.rf), Dims.special_n_d, s.na, ...
                    ones(1, length(Dims.n_bothz)), 0, Grids.d12_gridvals, s.ag, ...
                    bz_k, [], reg_rfvec{rr}, has_cont, 1.0, ev_k, ...
                    Dims.N_d_inner, Dims.N_a, 1};
            end
        end
        if is_exp_mode; w_mode = 'expasset'; else; w_mode = 'raw4d'; end
        w_args{w} = {sub_jobs, w_mode};
    end

    w_res = vfi_dispatch_chunks('ufhorz_multi_task_worker', w_args, pool_st.ram_dir, 2);

    % Scatter completed (region, z) columns back into each region's VKron & PKron
    for w = 1:n_work
        t_rng = (edges(w) + 1):edges(w + 1);
        v_list = w_res{w, 1};
        p_list = w_res{w, 2};
        for k = 1:numel(t_rng)
            ti = t_rng(k);
            rr = task_r(ti);
            zz = task_z(ti);
            st{rr}.VKron(:, zz, 1, j)    = v_list{k};
            st{rr}.PKron(1, :, zz, 1, j) = reshape(p_list{k}, [1, st{rr}.Dims.N_a]);
        end
    end
end

for r = 1:R
    s = st{r};
    [V_out{r}, Pol_out{r}] = UnKronUFHorz(s.VKron, s.PKron, [], [], s.nd, s.Dims.n_a1, s.na, s.nz, N_j_common, s.vfo, 0);
end
ok = true;

end
