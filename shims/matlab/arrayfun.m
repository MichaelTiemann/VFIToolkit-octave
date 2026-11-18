function varargout = arrayfun(ReturnFn, varargin)
% ARRAYFUN Octave shim supporting vectorized VFI Toolkit kernels and N-D grid expansion.

n_out = max(1, nargout);
varargout = cell(1, n_out);

% 1. Pass built-in allocators, cell/struct arrayfun calls, and Name-Value calls
%    ('UniformOutput', 'ErrorHandler') straight to Octave's built-in arrayfun
C = {@ones, @zeros, @nan, @inf, @true, @false};
has_char_opt = false;
for k = 1:numel(varargin)
    if ischar(varargin{k}) || iscell(varargin{k}) || isstruct(varargin{k})
        has_char_opt = true;
        break;
    end
end

if length(varargin) < 2 || has_char_opt || n_out > 1 || any(cellfun(@(x) isequal(x, ReturnFn), C))
    [varargout{:}] = builtin('arrayfun', ReturnFn, varargin{:});
    return;
end

func_str = func2str(ReturnFn);

% 2. Check persistent registry first, then caller/base vfoptions.vectorizedarrayfunnames
vectorized_names = vfi_vectorized_registry('get');

is_vectorized = false;
if ~isempty(vectorized_names)
    if any(strcmp(vectorized_names, 'FORCE_VECTORIZED'))
        is_vectorized = true;
    else
        for ii = 1:numel(vectorized_names)
            if ~isempty(vectorized_names{ii}) && ~isempty(strfind(func_str, vectorized_names{ii}))
                is_vectorized = true;
                break;
            end
        end
    end
end

if ~is_vectorized && evalin('base', "exist('vfoptions', 'var')")
    vfoptions_base = evalin('base', 'vfoptions');
    if isstruct(vfoptions_base) && isfield(vfoptions_base, 'vectorizedarrayfunnames')
        vn = vfoptions_base.vectorizedarrayfunnames;
        if ischar(vn); vn = {vn}; end
        for ii = 1:numel(vn)
            if ~isempty(vn{ii}) && ~isempty(strfind(func_str, vn{ii}))
                is_vectorized = true;
                break;
            end
        end
    end
end

% 3. Execute vectorized fast-path (with automatic singleton broadcast completion) or scalar fallback
if is_vectorized
    F = ReturnFn(varargin{:});

    % Ensure unused state dimensions (e.g. theta_c outside childhood stages) expand to full grid shape
    max_nd = ndims(F);
    last_arr_idx = 0;
    for i = numel(varargin):-1:1
        if (isnumeric(varargin{i}) || islogical(varargin{i})) && ~isscalar(varargin{i})
            last_arr_idx = i;
            break;
        end
    end
    if last_arr_idx > 0
        for i = 1:last_arr_idx
            max_nd = max(max_nd, ndims(varargin{i}));
        end
        full_sz = ones(1, max_nd);
        for i = 1:last_arr_idx
            sz = size(varargin{i});
            sz(end+1:max_nd) = 1;
            full_sz = max(full_sz, sz);
        end
        f_sz = size(F);
        f_sz(end+1:max_nd) = 1;
        if any(f_sz ~= full_sz)
            rep_fac = full_sz ./ f_sz;
            F = repmat(F, rep_fac);
        end
    end
    varargout{1} = F;
else
    varargout{1} = arrayfun_expand(ReturnFn, varargin{:});
end


end
