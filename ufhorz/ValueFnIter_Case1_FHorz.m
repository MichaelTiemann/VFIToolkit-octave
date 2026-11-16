function varargout=ValueFnIter_Case1_FHorz(n_d,n_a,n_z,N_j,d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions)
% Production UFHorz Dispatcher for ValueFnIter_Case1_FHorz.
% Typically, varargout=[V, Policy]

V=nan;
Policy=nan;

%% Check which vfoptions have been used, set all others to defaults
if exist('vfoptions','var')==0
    disp('No vfoptions given, using defaults')
    vfoptions.verbose=0;
    vfoptions.divideandconquer=0;
    vfoptions.gridinterplayer=0;
    vfoptions.lowmemory=0;
    vfoptions.incrementaltype=0;
    vfoptions.exoticpreferences='None';
    vfoptions.dynasty=0;
    vfoptions.experienceasset=0;
    vfoptions.experienceassetu=0;
    vfoptions.experienceassete=0;
    vfoptions.experienceassetz=0;
    vfoptions.experienceassetze=0;
    vfoptions.experienceassetsemiz=0;
    vfoptions.riskyasset=0;
    vfoptions.residualasset=0;
    vfoptions.n_ambiguity=0;
    vfoptions.n_e=0;
    vfoptions.n_semiz=0;
    vfoptions.parallel=1+(gpuDeviceCount>0);
    vfoptions.outputkron=0;
    vfoptions.alreadygridvals=0;
    vfoptions.alreadygridvals_semiexo=0;
else
    if ~isfield(vfoptions,'verbose'); vfoptions.verbose=0; end
    if ~isfield(vfoptions,'divideandconquer'); vfoptions.divideandconquer=0; end
    if ~isfield(vfoptions,'gridinterplayer')
        vfoptions.gridinterplayer=0;
    elseif vfoptions.gridinterplayer==1
        if ~isfield(vfoptions,'ngridinterp')
            error('When using vfoptions.gridinterplayer=1 you must set vfoptions.ngridinterp')
        end
    end
    if ~isfield(vfoptions,'lowmemory'); vfoptions.lowmemory=0; end
    if ~isfield(vfoptions,'incrementaltype'); vfoptions.incrementaltype=0; end
    if ~isfield(vfoptions,'exoticpreferences'); vfoptions.exoticpreferences='None'; end
    if ~isfield(vfoptions,'dynasty'); vfoptions.dynasty=0; end
    if ~isfield(vfoptions,'experienceasset'); vfoptions.experienceasset=0; end
    if ~isfield(vfoptions,'experienceassetu'); vfoptions.experienceassetu=0; end
    if ~isfield(vfoptions,'experienceassete'); vfoptions.experienceassete=0; end
    if ~isfield(vfoptions,'experienceassetz'); vfoptions.experienceassetz=0; end
    if ~isfield(vfoptions,'experienceassetze'); vfoptions.experienceassetze=0; end
    if ~isfield(vfoptions,'experienceassetsemiz'); vfoptions.experienceassetsemiz=0; end
    if ~isfield(vfoptions,'riskyasset'); vfoptions.riskyasset=0; end
    if ~isfield(vfoptions,'residualasset'); vfoptions.residualasset=0; end
    if ~isfield(vfoptions,'n_ambiguity'); vfoptions.n_ambiguity=0; end
    if ~isfield(vfoptions,'n_e'); vfoptions.n_e=0; end
    if ~isfield(vfoptions,'n_semiz'); vfoptions.n_semiz=0; end
    if ~isfield(vfoptions,'parallel'); vfoptions.parallel=1+(gpuDeviceCount>0); end
    if ~isfield(vfoptions,'outputkron'); vfoptions.outputkron=0; end
    if ~isfield(vfoptions,'alreadygridvals'); vfoptions.alreadygridvals=0; end
    if ~isfield(vfoptions,'alreadygridvals_semiexo'); vfoptions.alreadygridvals_semiexo=0; end
end

if isempty(n_d)
    error('If you have no d (decision) variables, set n_d=0;')
end
N_d=prod(n_d);
N_a=prod(n_a);
N_z=prod(n_z);
N_e=prod(vfoptions.n_e);

if ~all(size(d_grid)==[sum(n_d), 1])
    if ~isempty(n_d) && n_d(1)~=0
        error('d_grid is not the correct shape (should be of size sum(n_d)-by-1)')
    end
end
if ~all(size(a_grid)==[sum(n_a), 1])
    error('a_grid is not the correct shape (should be of size sum(n_a)-by-1; a (stacked) column vector)')
end

if vfoptions.parallel<2
    [V,Policy]=ValueFnIter_FHorz_CPU(n_d,n_a,n_z,N_j,d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, vfoptions);
    varargout={V,Policy};
    return
end

%% Prepare grids
d_grid=gpuArray(d_grid);
a_grid=gpuArray(a_grid);
z_grid=gpuArray(z_grid);
pi_z=gpuArray(pi_z);
if size(d_grid,2)==1
    d_gridvals=CreateGridvals(n_d,d_grid,1);
else
    d_gridvals=d_grid;
end

%% Exogenous shock gridvals and pi
if vfoptions.alreadygridvals==0
    [z_gridvals_J, pi_z_J, vfoptions]=ExogShockSetup_FHorz(n_z,z_grid,pi_z,N_j,Parameters,vfoptions,3,0);
    if N_z>0
        if ~all(pi_z_J(:)>=0)
            warning('Some elements of pi_z_J, the exogenous markov transition probabilities matrix, are negative')
        end
        if ~all(all(squeeze(sum(pi_z_J,2))-1 <1e-13))
            warning('Some rows of pi_z_J, the exogenous markov transition probabilities matrix, do not sum to one')
        end
    end
    if isfield(vfoptions,'pi_e_J')
        if ~all(vfoptions.pi_e_J(:)>=0)
            warning('Some elements of pi_e_J, the exogenous i.i.d. probabilities matrix, are negative')
        end
        if ~all(squeeze(sum(vfoptions.pi_e_J,1))-1 <1e-13)
            warning('Some columns of pi_e_J, the exogenous i.i.d. probabilities matrix, do not sum to one')
        end
    end
elseif vfoptions.alreadygridvals==1
    z_gridvals_J=z_grid;
    pi_z_J=pi_z;
end

%% Semi-exogenous shock gridvals and pi
if vfoptions.alreadygridvals_semiexo==0
    if prod(vfoptions.n_semiz)>0
        vfoptions=SemiExogShockSetup_FHorz(n_d,N_j,d_grid,Parameters,vfoptions,3);
    end
end

%% ReturnFn parameter names
if isempty(ReturnFnParamNames)
    ReturnFnParamNames=ReturnFnParamNamesFn(ReturnFn,n_d,n_a,n_z,N_j,vfoptions,Parameters);
end

if isfield(vfoptions,'WarmGlowBequestsFn')
    l_a=length(n_a);
    temp=getAnonymousFnInputNames(vfoptions.WarmGlowBequestsFn);
    vfoptions.WarmGlowBequestsFnParamsNames={temp{l_a+1:end}};
end

if vfoptions.verbose>=1
    vfoptions
end

%% Split n_d/n_a for non-standard endogenous states (experience assets, riskyasset, residualasset)
vfoptions=SetupNonStandardEndoStates_FHorz(n_d,n_a,d_grid,a_grid,vfoptions);

%% Exotic preferences dispatch
if ~any(strcmp(vfoptions.exoticpreferences,{'None','QuasiHyperbolic','EpsteinZin','GulPesendorfer','AmbiguityAversion'}))
    error(['vfoptions.exoticpreferences=',vfoptions.exoticpreferences,' is not a recognized option'])
end
if strcmp(vfoptions.exoticpreferences,'QuasiHyperbolic')
    [V, Policy, Valt, Policyalt] = solve_ufhorz_local();
    if strcmp(vfoptions.quasi_hyperbolic,'Naive')
        varargout = {V, Policy, Valt, Policyalt};
    elseif strcmp(vfoptions.quasi_hyperbolic,'Sophisticated')
        varargout = {V, Policy, Valt};
    end
    return
elseif strcmp(vfoptions.exoticpreferences,'EpsteinZin')
    [V, Policy] = solve_ufhorz_local();
    varargout = {V, Policy};
    return
elseif strcmp(vfoptions.exoticpreferences,'GulPesendorfer')
    [V, Policy]=ValueFnIter_FHorz_GulPesendorfer(n_d,n_a,n_z,N_j,d_gridvals,a_grid,z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    varargout={V, Policy};
    return
elseif strcmp(vfoptions.exoticpreferences,'AmbiguityAversion')
    [V, Policy]=ValueFnIter_FHorz_AmbiguityAversion(n_d,n_a,n_z,N_j,d_grid,a_grid,z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    varargout={V, Policy};
    return
end

%% Special legacy-only modes (ResidualAsset, StateDependentVariables_z, Dynasty)
if vfoptions.residualasset==1
    n_a1=vfoptions.n_a1; n_r=vfoptions.n_r; a1_grid=vfoptions.a1_grid; r_grid=vfoptions.r_grid;
    [V,Policy]=ValueFnIter_FHorz_ResidAsset(n_d,n_a1,n_r,n_z, N_j, d_grid, a1_grid, r_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    varargout={V, Policy};
    return
end

if isfield(vfoptions,'StateDependentVariables_z')==1
    if N_d==0
        [VKron,PolicyKron]=ValueFnIter_FHorz_nod_SDVz_raw(n_a, n_z, N_j, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        PolicyKron=shiftdim(PolicyKron,-1);
    else
        [VKron, PolicyKron]=ValueFnIter_FHorz_SDVz_raw(n_d,n_a,n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    end
    [V, Policy] = UnKronUFHorz(VKron, PolicyKron, [], [], n_d, n_a, n_a, n_z, N_j, vfoptions, 0);
    varargout={V, Policy};
    return
end

if vfoptions.dynasty==1
    if ~isfield(vfoptions,'tolerance'); vfoptions.tolerance=10^(-9); end
    if N_d==0
        [VKron,PolicyKron]=ValueFnIter_FHorz_Dynasty_nod_raw(n_a, n_z, N_j, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        PolicyKron=shiftdim(PolicyKron,-1);
    else
        [VKron, PolicyKron]=ValueFnIter_FHorz_Dynasty_raw(n_d,n_a,n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
    end
    [V, Policy] = UnKronUFHorz(VKron, PolicyKron, [], [], n_d, n_a, n_a, n_z, N_j, vfoptions, 0);
    varargout={V, Policy};
    return
end

%% Unified UFHorz Dispatch (ExperienceAsset, RiskyAsset, SemiExo, Standard)
[V, Policy] = solve_ufhorz_local();
varargout = {V, Policy};

    function [V_out, Pol_out, Valt_out, Polalt_out] = solve_ufhorz_local()
        if vfoptions.divideandconquer == 1 || vfoptions.gridinterplayer == 1
            if exist('ValueFnIter_UFHorz_DC', 'file') == 0 && vfoptions.divideandconquer == 1
                error('UFHorz divide-and-conquer solvers are not installed in VFIToolkit-octave.');
            end
            if exist('ValueFnIter_UFHorz_GI', 'file') == 0 && vfoptions.gridinterplayer == 1
                error('UFHorz grid-interpolation solvers are not installed in VFIToolkit-octave.');
            end
        end

        if vfoptions.experienceasset>=1 || vfoptions.experienceassetu>=1 || vfoptions.experienceassete>=1 || vfoptions.experienceassetz>=1 || vfoptions.experienceassetze>=1 || vfoptions.experienceassetsemiz>=1
            [V_out, Pol_out, Valt_out, Polalt_out] = ValueFnIter_UFHorz_ExpAsset(n_d, n_a, n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        elseif vfoptions.riskyasset == 1
            [V_out, Pol_out, Valt_out, Polalt_out] = ValueFnIter_UFHorz_RiskyAsset(n_d, n_a, n_z, N_j, d_grid, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        elseif vfoptions.divideandconquer == 1 && vfoptions.gridinterplayer == 1
            [V_out, Pol_out, Valt_out, Polalt_out] = ValueFnIter_UFHorz_DC_GI(n_d, n_a, n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        elseif vfoptions.gridinterplayer == 1
            [V_out, Pol_out, Valt_out, Polalt_out] = ValueFnIter_UFHorz_GI(n_d, n_a, n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        elseif vfoptions.divideandconquer == 1
            [V_out, Pol_out, Valt_out, Polalt_out] = ValueFnIter_UFHorz_DC(n_d, n_a, n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
        else
            [VK_tmp, PK_tmp, VaK_tmp, PaK_tmp] = ValueFnIter_UFHorz_raw(n_d, n_a, n_z, N_j, d_gridvals, a_grid, z_gridvals_J, pi_z_J, ReturnFn, Parameters, DiscountFactorParamNames, ReturnFnParamNames, vfoptions);
            [V_out, Pol_out, Valt_out, Polalt_out] = UnKronUFHorz(VK_tmp, PK_tmp, VaK_tmp, PaK_tmp, n_d, n_a, n_a, n_z, N_j, vfoptions, 0);
        end
    end

end
