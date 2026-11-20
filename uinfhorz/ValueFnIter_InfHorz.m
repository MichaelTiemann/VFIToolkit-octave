function [V, Policy] = ValueFnIter_InfHorz(n_d, n_a, n_z, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)
% VALUEFNITER_INFHORZ Streamlined Howard Policy-Iteration Solver for Standard Infinite-Horizon Models.

if exist('ReturnFnParamNames', 'var') == 0
    ReturnFnParamNames = [];
end
if exist('vfoptions', 'var') == 0 || isempty(vfoptions)
    vfoptions = struct();
end
if ~isfield(vfoptions, 'tolerance');    vfoptions.tolerance    = 1e-9; end
if ~isfield(vfoptions, 'maxiter');      vfoptions.maxiter      = 2000; end
if ~isfield(vfoptions, 'howards');      vfoptions.howards      = 80;   end
if ~isfield(vfoptions, 'maxhowards');   vfoptions.maxhowards   = 500;  end
if ~isfield(vfoptions, 'verbose');      vfoptions.verbose      = 0;    end
if ~isfield(vfoptions, 'outputkron');   vfoptions.outputkron   = 0;    end
if ~isfield(vfoptions, 'lowmemory');    vfoptions.lowmemory    = 0;    end

if isempty(n_d); n_d = 0; end
N_d = prod(n_d);
N_a = prod(n_a);
N_z = prod(n_z);
has_d = (N_d > 0);
has_z = (N_z > 0);

a_grid = vfi_gpu(a_grid(:));
if has_d
    d_grid = vfi_gpu(d_grid(:));
    d_gridvals = CreateGridvals(n_d, d_grid, 1);
    spec_n_d = n_d;
else
    d_gridvals = [];
    spec_n_d = 0;
end

if has_z
    pi_z = vfi_gpu(pi_z);
    if size(z_grid, 1) == sum(n_z) && size(z_grid, 2) == 1
        z_gridvals = CreateGridvals(n_z, vfi_gpu(z_grid), 1);
    else
        z_gridvals = vfi_gpu(z_grid);
    end
    spec_n_z = n_z;
else
    z_gridvals = [];
    spec_n_z = 0;
    N_z = 1;
    pi_z = 1;
end

if isempty(ReturnFnParamNames)
    l_d = 0; if has_d; l_d = length(n_d); end
    l_a = length(n_a);
    l_z = 0; if has_z; l_z = length(n_z); end
    n_state_args = l_d + 2 * l_a + l_z;
    fn_args = getAnonymousFnInputNames(ReturnFn);
    if length(fn_args) > n_state_args
        ReturnFnParamNames = fn_args(n_state_args + 1 : end);
    else
        ReturnFnParamNames = {};
    end
end

ReturnFnParamsVec = CreateVectorFromParams(Parameters, ReturnFnParamNames);
beta = prod(CreateVectorFromParams(Parameters, DiscountFactorParamNames));

RM = CreateReturnFnMatrix_UDisc(ReturnFn, spec_n_d, n_a, spec_n_z, 0, d_gridvals, a_grid, z_gridvals, [], ReturnFnParamsVec, 0);
N_choice = max(N_d, 1) * N_a;
RM = reshape(RM, [N_choice, N_a, N_z]);
if has_d && N_d > 1
    RM_4D = reshape(RM, [N_d, N_a, N_a, N_z]);
end

% Note that we wrap gpuArray around zeros(...) because zeros(..., 'gpuArray') is hijacked by MATLAB's JIT
VKron = vfi_gpu(zeros(N_a, N_z));
PolicyKron = vfi_gpu(ones(N_a, N_z));
pi_z_T = pi_z';
has_piz_pos = double(pi_z_T > 0);

az_offset = N_choice * ((0:(N_a * N_z - 1))');
z_offset_ev = N_a * repelem((0:(N_z - 1))', N_a, 1);

tol = vfoptions.tolerance;
howard_steps = vfoptions.howards;

for iter = 1:vfoptions.maxiter
    EV_inf = (VKron == -Inf);
    if any(EV_inf(:))
        V_safe = VKron;
        V_safe(EV_inf) = 0;
        EV = V_safe * pi_z_T;
        EV((double(EV_inf) * has_piz_pos) > 0) = -Inf;
    else
        EV = VKron * pi_z_T;
    end

    if has_d && N_d > 1
        entireRHS = reshape(RM_4D + reshape(beta * EV, [1, N_a, 1, N_z]), [N_choice, N_a, N_z]);
    else
        entireRHS = RM + reshape(beta * EV, [N_a, 1, N_z]);
    end
    [V_new, Pol_new] = max(entireRHS, [], 1);
    V_new   = reshape(V_new,   [N_a, N_z]);
    Pol_new = reshape(Pol_new, [N_a, N_z]);

    fin = isfinite(V_new) & isfinite(VKron);
    if any(fin(:))
        curr_dist = max(abs(V_new(fin) - VKron(fin)));
    else
        curr_dist = 0;
    end

    same_pol = isequal(Pol_new, PolicyKron);
    VKron = V_new;
    PolicyKron = Pol_new;

    if curr_dist < tol || (same_pol && iter > 2 && curr_dist < 1e-6)
        break;
    end

    if iter <= vfoptions.maxhowards && howard_steps > 0
        F_pol = reshape(RM(Pol_new(:) + az_offset), [N_a, N_z]);
        if has_d
            ap_pol = ceil(Pol_new(:) / N_d);
        else
            ap_pol = Pol_new(:);
        end
        ev_lin_idx = ap_pol + z_offset_ev;
        V_how = VKron;
        if all(isfinite(F_pol(:))) && ~any(EV_inf(:))
            for h_it = 1:howard_steps
                EV_h = V_how * pi_z_T;
                V_how = F_pol + beta * reshape(EV_h(ev_lin_idx), [N_a, N_z]);
            end
        elseif any(isfinite(F_pol(:)))
            % Keep Howard acceleration active on finite states even if boundary states have -Inf
            for h_it = 1:howard_steps
                Vh_inf = ~isfinite(V_how);
                Vh_safe = V_how;
                Vh_safe(Vh_inf) = 0;
                EV_h = Vh_safe * pi_z_T;
                EV_h((double(Vh_inf) * has_piz_pos) > 0) = -Inf;
                V_how = F_pol + beta * reshape(EV_h(ev_lin_idx), [N_a, N_z]);
            end
        end
        VKron = V_how;
    end
end

if vfoptions.verbose == 1
    fprintf('ValueFnIter_InfHorz converged in %d iterations (dist = %.2e)\n', iter, curr_dist);
end

if vfoptions.outputkron == 1
    V = VKron;
    Policy = PolicyKron;
    return;
end

if has_z
    state_dims = [n_a, n_z];
else
    state_dims = n_a;
    if isscalar(state_dims); state_dims = [state_dims, 1]; end
end
V = reshape(VKron, state_dims);

l_a = length(n_a);
if ~has_d
    if l_a == 1
        Policy = reshape(PolicyKron, state_dims);
    else
        Policy = vfi_gpu(zeros([l_a, state_dims]));
        a_cum = 1;
        for i = 1:l_a
            Policy(i, :) = rem(ceil(PolicyKron(:)' / a_cum) - 1, n_a(i)) + 1;
            a_cum = a_cum * n_a(i);
        end
    end
else
    l_d = length(n_d);
    n_rows = l_d + l_a;
    Policy = vfi_gpu(zeros([n_rows, state_dims]));
    d_idx = rem(PolicyKron(:)' - 1, N_d) + 1;
    a_idx = ceil(PolicyKron(:)' / N_d);
    d_cum = 1;
    for i = 1:l_d
        Policy(i, :) = rem(ceil(d_idx / d_cum) - 1, n_d(i)) + 1;
        d_cum = d_cum * n_d(i);
    end
    a_cum = 1;
    for i = 1:l_a
        Policy(l_d + i, :) = rem(ceil(a_idx / a_cum) - 1, n_a(i)) + 1;
        a_cum = a_cum * n_a(i);
    end
end


end
