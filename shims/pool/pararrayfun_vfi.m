function varargout = pararrayfun_vfi(func, is_vectorized, varargin)
% PARARRAYFUN_VFI Generalized persistent-pool parallel array/map-reduce dispatcher.
% Works for both standard VFIToolkit implicit-expansion arrayfun calls AND
% custom fused Bellman map-reduce workers (via vfoptions.slice_plan).

num_outs = max(1, nargout);
num_args = numel(varargin);

if ~exist('is_vectorized', 'var') || isempty(is_vectorized)
    is_vectorized = false;
end

% 1. Locate pool config (from trailing vfoptions struct if present, else vfi_pool('status'))
has_vfopt = (num_args >= 1) && isstruct(varargin{num_args}) && ...
    (isfield(varargin{num_args}, 'n_proc') || isfield(varargin{num_args}, 'ram_dir'));

if has_vfopt
    vfoptions = varargin{num_args};
    pool_st   = vfi_pool('status');
    if isfield(vfoptions, 'n_proc') && ~isempty(vfoptions.n_proc)
        ncores = vfoptions.n_proc;
    else
        ncores = pool_st.ncores;
    end
    if isfield(vfoptions, 'ram_dir') && ~isempty(vfoptions.ram_dir)
        ram_dir = vfoptions.ram_dir;
    else
        ram_dir = pool_st.ram_dir;
    end
else
    pool_st   = vfi_pool('status');
    ncores    = pool_st.ncores;
    ram_dir   = pool_st.ram_dir;
    vfoptions = struct();
end

% Ensure pool is actually running before attempting binary dispatch
if ncores > 1 && (isempty(ram_dir) || ~exist(ram_dir, 'dir'))
    pool_st = vfi_pool('ensure', ncores);
    ncores  = pool_st.ncores;
    ram_dir = pool_st.ram_dir;
end

% 2. Determine slicing plan: Explicit map-reduce plan OR generic broadcast dimension
has_plan = has_vfopt && isfield(vfoptions, 'slice_plan') && ~isempty(vfoptions.slice_plan);

if has_plan
    plan       = vfoptions.slice_plan;
    arg_dims   = plan.arg_dims;     % length == num_args; 0 means pass through unsliced
    concat_dim = plan.concat_dim;
    N          = plan.N;
    ncores     = min(ncores, max(1, N));
else
    % Generic VFIToolkit implicit-expansion slicing:
    % Only non-scalar numeric/logical arrays participate in broadcast shape.
    % (Trailing 1D parameter vectors like ReturnFnParamsVec are only present in
    %  explicitly vectorized calls; shield non-broadcast args if trailing vfoptions present).
    scan_limit = num_args - double(has_vfopt);
    max_ndims  = 2;
    is_grid    = false(1, num_args);

    for i = 1:scan_limit
        vi = varargin{i};
        if (isnumeric(vi) || islogical(vi)) && ~isscalar(vi)
            is_grid(i) = true;
            max_ndims  = max(max_ndims, ndims(vi));
        end
    end

    sz = ones(1, max_ndims);
    for i = 1:scan_limit
        if is_grid(i)
            arg_sz = size(varargin{i});
            % Ignore 1D parameter vectors that conflict with established grid dims
            padded = ones(1, max_ndims);
            padded(1:numel(arg_sz)) = arg_sz;
            if all(padded == 1 | sz == 1 | padded == sz)
                sz = max(sz, padded);
            else
                is_grid(i) = false;
            end
        end
    end

    % Pick the OUTER-MOST column-major dimension >= ncores for contiguous memory slabs;
    % fallback to the single largest dimension overall (NEVER clamp to tiny dims!).
    cand_dims = find(sz >= ncores);
    if ~isempty(cand_dims)
        split_dim = cand_dims(end);
    else
        [~, split_dim] = max(sz);
    end

    N          = sz(split_dim);
    ncores     = min(ncores, max(1, N));
    concat_dim = split_dim;
    arg_dims   = zeros(1, num_args);
    for i = 1:scan_limit
        if is_grid(i) && size(varargin{i}, split_dim) == N && N > 1
            arg_dims(i) = split_dim;
        end
    end
end

% 3. Sequential fallback for ncores <= 1 or trivial problems
if ncores <= 1 || N <= 1
    if has_plan && has_vfopt
        varargin{num_args} = rmfield(varargin{num_args}, 'slice_plan');
    end
    varargout = cell(1, num_outs);
    if is_vectorized
        [varargout{:}] = feval(func, varargin{:});
    else
        [varargout{:}] = arrayfun_expand(func, varargin{:});
    end
    return;
end

% 4. Sanitize trailing vfoptions once (strip unserializable function_handles)
if has_vfopt
    vfopt_clean = vfoptions;
    if isfield(vfopt_clean, 'slice_plan')
        vfopt_clean = rmfield(vfopt_clean, 'slice_plan');
    end
    fn_fields = fieldnames(vfopt_clean);
    for f = 1:numel(fn_fields)
        val = vfopt_clean.(fn_fields{f});
        if isa(val, 'function_handle')
            vfopt_clean = rmfield(vfopt_clean, fn_fields{f});
        end
    end
end

if isa(func, 'function_handle')
    func_name = func2str(func);
else
    func_name = func;
end

% 5. Slice & stream directly to .bin files (low master RAM footprint)
edges         = round(linspace(0, N, ncores + 1));
valid_workers = [];

for c = 1:ncores
    idx = (edges(c) + 1):edges(c + 1);
    if isempty(idx)
        continue;
    end
    valid_workers(end + 1) = c; %#ok<AGROW>

    args = varargin;
    if has_vfopt
        args{num_args} = vfopt_clean;
    end

    for a = 1:num_args
        sd = arg_dims(a);
        if sd > 0 && ~isempty(varargin{a})
            nd = max(sd, ndims(varargin{a}));
            S.type = '()';
            S.subs = repmat({':'}, 1, nd);
            S.subs{sd} = idx;
            args{a} = subsref(varargin{a}, S);
        end
    end

    func     = func_name; %#ok<NASGU>
    temp_in  = sprintf('%s/vfi_worker_%d_in_tmp.bin', ram_dir, c);
    in_file  = sprintf('%s/vfi_worker_%d_in.bin', ram_dir, c);
    out_file = sprintf('%s/vfi_worker_%d_out.bin', ram_dir, c);
    if exist(out_file, 'file'); delete(out_file); end

    save('-binary', temp_in, 'func', 'args', 'is_vectorized', 'num_outs');
    rename(temp_in, in_file);
end

% 6. Collect worker outputs (.bin) with proper worker error propagation
K         = numel(valid_workers);
results   = cell(K, num_outs);
done_mask = false(K, 1);
completed = 0;

while completed < K
    for k = 1:K
        if ~done_mask(k)
            c = valid_workers(k);
            out_file = sprintf('%s/vfi_worker_%d_out.bin', ram_dir, c);
            if exist(out_file, 'file')
                loaded = false;
                try
                    data = load('-binary', out_file, 'result');
                    delete(out_file);
                    loaded = true;
                catch
                    % File still mid-rename; retry next poll
                end

                if loaded
                    % Check worker exceptions OUTSIDE try/catch so errors aren't swallowed!
                    if isstruct(data.result) && isfield(data.result, 'message')
                        error('Worker %d exception: %s', c, data.result.message);
                    elseif isa(data.result, 'MException')
                        rethrow(data.result);
                    end

                    if iscell(data.result) && numel(data.result) == num_outs
                        for o = 1:num_outs
                            results{k, o} = data.result{o};
                        end
                    else
                        results{k, 1} = data.result;
                    end
                    done_mask(k) = true;
                    completed = completed + 1;
                end
            end
        end
    end
    if completed < K
        pause(0.0005);
    end
end

% 7. Concatenate worker chunks along concat_dim
varargout = cell(1, num_outs);
for o = 1:num_outs
    varargout{o} = cat(concat_dim, results{:, o});
end


end
