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

a_grid = gpuArray(a_grid(:));
if has_d
    d_grid = gpuArray(d_grid(:));
    d_gridvals = CreateGridvals(n_d, d_grid, 1);
    spec_n_d = n_d;
else
    d_gridvals = [];
    spec_n_d = 0;
end

if has_z
    pi_z = gpuArray(pi_z);
    if size(z_grid, 1) == sum(n_z) && size(z_grid, 2) == 1
        z_gridvals = CreateGridvals(n_z, gpuArray(z_grid), 1);
    else
        z_gridvals = gpuArray(z_grid);
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

VKron = zeros(N_a, N_z, 'gpuArray');
PolicyKron = ones(N_a, N_z, 'gpuArray');
pi_z_T = pi_z';

az_offset = N_choice * ((0:(N_a * N_z - 1))');
z_offset_ev = N_a * repelem((0:(N_z - 1))', N_a, 1);

tol = vfoptions.tolerance;
howard_steps = vfoptions.howards;

for iter = 1:vfoptions.maxiter
    EV_inf = (VKron == -Inf);
    V_safe = VKron;
    V_safe(EV_inf) = -1e250;
    EV = V_safe * pi_z_T;
    if any(EV_inf(:))
        EV((double(EV_inf) * double(pi_z_T > 0)) > 0) = -Inf;
    end

    if has_d
        EV_expanded = repelem(reshape(EV, [N_a, 1, N_z]), N_d, 1, 1);
    else
        EV_expanded = reshape(EV, [N_a, 1, N_z]);
    end

    entireRHS = RM + beta * EV_expanded;
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
        if all(isfinite(F_pol(:)))
            if has_d
                ap_pol = ceil(Pol_new(:) / N_d);
            else
                ap_pol = Pol_new(:);
            end
            ev_lin_idx = ap_pol + z_offset_ev;
            V_how = VKron;
            for h_it = 1:howard_steps
                EV_h = V_how * pi_z_T;
                V_how = F_pol + beta * reshape(EV_h(ev_lin_idx), [N_a, N_z]);
            end
            VKron = V_how;
        end
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
        Policy = zeros([l_a, state_dims], 'gpuArray');
        a_cum = 1;
        for i = 1:l_a
            Policy(i, :) = rem(ceil(PolicyKron(:)' / a_cum) - 1, n_a(i)) + 1;
            a_cum = a_cum * n_a(i);
        end
    end
else
    l_d = length(n_d);
    n_rows = l_d + l_a;
    Policy = zeros([n_rows, state_dims], 'gpuArray');
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
