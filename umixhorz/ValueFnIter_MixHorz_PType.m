function [V, Policy]=ValueFnIter_MixHorz_PType(n_d,n_a,n_z, N_j,Names_i,d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, vfoptions)

%
% vfoptions.verbose=1 will give feedback
% vfoptions.verboseparams=1 will give further feedback on the param values of each permanent type
%
V=struct();
Policy=struct();

% N_d=prod(n_d);
% N_a=prod(n_a);
% N_z=prod(n_z);
% N_i=prod(n_i);

if iscell(Names_i)
    N_i=length(Names_i);
else
    N_i=Names_i; % It is the number of PTypes (which have not been given names)
    Names_i={'ptype001'};
    for ii=2:N_i
        if ii<10
            Names_i{ii}=['ptype00',num2str(ii)];
        elseif ii<100
            Names_i{ii}=['ptype0',num2str(ii)];
        elseif ii<1000
            Names_i{ii}=['ptype',num2str(ii)];
        end
    end
end

pool_st = struct('active', false, 'ncores', 0, 'ram_dir', '');
if exist('OCTAVE_VERSION', 'builtin') ~= 0 && exist('vfi_pool', 'file') ~= 0 ...
        && (~exist('vfoptions', 'var') || ~isfield(vfoptions, 'in_worker') || ~vfoptions.in_worker)
    pool_st = vfi_pool('status');
end
par_jobs  = {};
par_idx   = [];
par_s_cpu = [];

for ii=1:N_i
    iistr=Names_i{ii};

    % First set up vfoptions
    if exist('vfoptions','var')
        vfoptions_temp=PType_Options(vfoptions,iistr);
        if ~isfield(vfoptions_temp,'verbose')
            vfoptions_temp.verbose=0;
        end
        if ~isfield(vfoptions_temp,'verboseparams')
            vfoptions_temp.verboseparams=0;
        end
        if ~isfield(vfoptions_temp,'ptypestorecpu')
            vfoptions_temp.ptypestorecpu=0; % GPU memory is limited, so switch solutions to the cpu. Off by default.
        end
    else
        vfoptions_temp.verbose=0;
        vfoptions_temp.verboseparams=0;
        vfoptions_temp.ptypestorecpu=0; % GPU memory is limited, so switch solutions to the cpu. Off by default.
    end

    if vfoptions_temp.verbose==1
        fprintf('Permanent type: %i of %i \n',ii, N_i)
    end

    % Go through everything which might be dependent on fixed type (PType)
    % [THIS could be better coded, 'names' are same for all these and just need to be found once outside of ii loop]
    if isstruct(n_d)
        n_d_temp=n_d.(iistr);
    else
        n_d_temp=n_d;
    end
    if isstruct(n_a)
        n_a_temp=n_a.(iistr);
    else
        n_a_temp=n_a;
    end
    if isstruct(n_z)
        n_z_temp=n_z.(iistr);
    else
        n_z_temp=n_z;
    end
    if isstruct(N_j)
        N_j_temp=N_j.(iistr);
    else
        N_j_temp=N_j;
    end
    if isstruct(d_grid)
        d_grid_temp=d_grid.(iistr);
    else
        d_grid_temp=d_grid;
    end
    if isstruct(a_grid)
        a_grid_temp=a_grid.(iistr);
    else
        a_grid_temp=a_grid;
    end

    %% Exogenous shocks
    if isstruct(z_grid)
        z_grid_temp=z_grid.(iistr);
    else
        nn=size(z_grid,ndims(z_grid));
        if nn==N_i
            otherdims = repmat({':'},1,ndims(z_grid)-1);
            z_grid_temp=z_grid(otherdims{:},ii);
        else
            z_grid_temp=z_grid;
        end
    end
    if isstruct(pi_z)
        pi_z_temp=pi_z.(iistr);
    else
        nn=size(pi_z,ndims(pi_z));
        if nn==N_i
            otherdims = repmat({':'},1,ndims(pi_z)-1);
            pi_z_temp=pi_z(otherdims{:},ii);
        else
            pi_z_temp=pi_z;
        end
    end

    % e
    if prod(vfoptions_temp.n_e)>0
        % If vfoptions_temp.e_grid is a structure that was already dealt with by PType_Options() command
        if ~isstruct(vfoptions.e_grid)
            % So just need to check if last dimension is of length N_i
            nn=size(vfoptions_temp.e_grid,ndims(vfoptions_temp.e_grid));
            if nn==N_i
                otherdims = repmat({':'},1,ndims(vfoptions_temp.e_grid)-1);
                vfoptions_temp.e_grid=vfoptions_temp.e_grid(otherdims{:},ii);
            end
        end
        % If vfoptions_temp.pi_semiz is a structure that was already dealt with by PType_Options() command
        if ~isstruct(vfoptions.pi_e)
            % So just need to check if last dimension is of length N_i
            nn=size(vfoptions_temp.pi_e,ndims(vfoptions_temp.pi_e));
            if nn==N_i
                otherdims = repmat({':'},1,ndims(vfoptions_temp.pi_e)-1);
                vfoptions_temp.pi_e=vfoptions_temp.pi_e(otherdims{:},ii);
            end
        end
    end

    % semiz
    if prod(vfoptions_temp.n_semiz)>0
        % If vfoptions_temp.semiz_grid is a structure that was already dealt with by PType_Options() command
        if ~isstruct(vfoptions.semiz_grid)
            % So just need to check if last dimension is of length N_i
            nn=size(vfoptions_temp.semiz_grid,ndims(vfoptions_temp.semiz_grid));
            if nn==N_i
                otherdims = repmat({':'},1,ndims(vfoptions_temp.semiz_grid)-1);
                vfoptions_temp.semiz_grid=vfoptions_temp.semiz_grid(otherdims{:},ii);
            end
        end
        % Might use SemiExoShockFn or pi_semiz, if the later we need to deal with it
        if isfield(vfoptions_temp,'pi_semiz')
            % If vfoptions_temp.pi_semiz is a structure that was already dealt with by PType_Options() command
            if ~isstruct(vfoptions.pi_semiz)
                % So just need to check if last dimension is of length N_i
                nn=size(vfoptions_temp.pi_semiz,ndims(vfoptions_temp.pi_semiz));
                if nn==N_i
                    otherdims = repmat({':'},1,ndims(vfoptions_temp.pi_semiz)-1);
                    vfoptions_temp.pi_semiz=vfoptions_temp.pi_semiz(otherdims{:},ii);
                end
            end
        end
    end


    %%
    DiscountFactorParamNames_temp=DiscountFactorParamNames;
    if isstruct(DiscountFactorParamNames)
        names=fieldnames(DiscountFactorParamNames);
        for jj=1:length(names)
            if strcmp(names{jj},Names_i{ii})
                DiscountFactorParamNames_temp=DiscountFactorParamNames.(names{jj});
            end
        end
    end

    if isstruct(ReturnFn)
        ReturnFn_temp=ReturnFn.(iistr);
    else
        ReturnFn_temp=ReturnFn;
    end

    %%
    % Parameters are allowed to be given as structure, or as vector/matrix
    % (in terms of their dependence on fixed type). So go through each of
    % these in term.
    Parameters_temp=Parameters;
    FullParamNames=fieldnames(Parameters);
    nFields=length(FullParamNames);
    for kField=1:nFields
        if isa(Parameters.(FullParamNames{kField}), 'struct') % Check for permanent type in structure form
            names=fieldnames(Parameters.(FullParamNames{kField}));
            for jj=1:length(names)
                if strcmp(names{jj},Names_i{ii})
                    Parameters_temp.(FullParamNames{kField})=Parameters.(FullParamNames{kField}).(names{jj});
                end
            end
        elseif any(size(Parameters.(FullParamNames{kField}))==N_i) % Check for permanent type in vector/matrix form.
            temp=Parameters.(FullParamNames{kField});
            [~,ptypedim]=max(size(Parameters.(FullParamNames{kField}))==N_i); % Parameters as vector/matrix can be at most two dimensional, figure out which relates to PType.
            if ptypedim==1
                Parameters_temp.(FullParamNames{kField})=temp(ii,:);
            elseif ptypedim==2
                Parameters_temp.(FullParamNames{kField})=temp(:,ii);
            end
        end
    end

    % ReturnFnParamNames_temp=ReturnFnParamNamesFn(ReturnFn_temp,n_d_temp,n_a_temp,n_z_temp,vfoptions_temp,Parameters_temp);

    if vfoptions_temp.verboseparams==1
        sprintf('Parameter values for the current permanent type')
        Parameters_temp
    end

    % Batch InfHorz or lightweight FHorz PTypes (<= 4e6 RHS ops/period) concurrently across workers
    step_ops = max(1, prod(n_d_temp)) * (prod(n_a_temp)^2) * max(1, prod(n_z_temp));
    if pool_st.active && pool_st.ncores > 1 && N_i > 1 && (~isfinite(N_j_temp) || step_ops <= 4e6)
        vfoptions_temp.in_worker = true;
        par_idx(end+1)   = ii; %#ok<AGROW>
        par_s_cpu(end+1) = vfoptions_temp.ptypestorecpu; %#ok<AGROW>
        par_jobs{end+1}  = {'', isfinite(N_j_temp), func2str(ReturnFn_temp), ...
            n_d_temp, n_a_temp, n_z_temp, N_j_temp, d_grid_temp, a_grid_temp, ...
            z_grid_temp, pi_z_temp, Parameters_temp, DiscountFactorParamNames_temp, vfoptions_temp}; %#ok<AGROW>
        par_jobs{end} = par_jobs{end}(2:end);
        continue;
    end

    if isfinite(N_j_temp)
        [V_ii, Policy_ii]=ValueFnIter_Case1_FHorz(n_d_temp,n_a_temp,n_z_temp,N_j_temp,d_grid_temp, a_grid_temp, z_grid_temp, pi_z_temp, ReturnFn_temp, Parameters_temp, DiscountFactorParamNames_temp, [], vfoptions_temp);
    else % PType actually allows for infinite horizon as well
        [V_ii, Policy_ii]=ValueFnIter_InfHorz(n_d_temp,n_a_temp,n_z_temp,d_grid_temp, a_grid_temp, z_grid_temp, pi_z_temp, ReturnFn_temp, Parameters_temp, DiscountFactorParamNames_temp, [], vfoptions_temp);
    end


    if vfoptions_temp.ptypestorecpu==1
        V.(iistr)=gather(V_ii);
        Policy.(iistr)=gather(Policy_ii);
    else
        V.(iistr)=V_ii;
        Policy.(iistr)=Policy_ii;
    end

    clear V_ii Policy_ii

end

% Execute batched InfHorz / lightweight FHorz PTypes concurrently across persistent workers
if ~isempty(par_jobs)
    K_par = numel(par_jobs);
    for k = 1:K_par
        vfo_k = par_jobs{k}{13};
        fn_flds = fieldnames(vfo_k);
        for f = 1:numel(fn_flds)
            fv = vfo_k.(fn_flds{f});
            if isa(fv, 'function_handle')
                vfo_k.([fn_flds{f}, '_fhstr']) = func2str(fv);
                vfo_k = rmfield(vfo_k, fn_flds{f});
            end
        end
        par_jobs{k}{13} = vfo_k;
    end
    if K_par <= pool_st.ncores
        w_res = vfi_dispatch_chunks('ptype_vfi_worker', par_jobs, pool_st.ram_dir, 2);
        for k = 1:K_par
            iistr = Names_i{par_idx(k)};
            if par_s_cpu(k) == 1
                V.(iistr)      = gather(w_res{k, 1});
                Policy.(iistr) = gather(w_res{k, 2});
            else
                V.(iistr)      = w_res{k, 1};
                Policy.(iistr) = w_res{k, 2};
            end
        end
    else
        for k = 1:K_par
            [V_ii, Policy_ii] = ptype_vfi_worker(par_jobs{k}{:});
            iistr = Names_i{par_idx(k)};
            V.(iistr)      = V_ii;
            Policy.(iistr) = Policy_ii;
        end
    end
end


end
