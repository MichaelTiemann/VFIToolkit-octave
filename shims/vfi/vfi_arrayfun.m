function varargout = vfi_arrayfun(ReturnFn, varargin)
%VFI_ARRAYFUN GPU-aware and CPU-vectorized N-D grid evaluator for UFHorz / UInfHorz.
%   Dispatches to native CUDA arrayfun when any input is a gpuArray; otherwise uses
%   the vectorized registry fast-path (with singleton broadcast completion) or
%   arrayfun_expand on CPU (MATLAB No-GPU and GNU Octave).

n_out = max(1, nargout);
varargout = cell(1, n_out);

% 1. Native CUDA fast-path when running on MATLAB with gpuArray inputs
if exist('OCTAVE_VERSION', 'builtin') == 0
    for k = 1:numel(varargin)
        if isa(varargin{k}, 'gpuArray')
            [varargout{:}] = arrayfun(ReturnFn, varargin{:});
            return;
        end
    end
end

% 2. Standard built-in arrayfun pass-through for Name-Value / cell / struct calls
C = {@ones, @zeros, @nan, @inf, @true, @false};
has_char_opt = false;
for k = 1:numel(varargin)
    if ischar(varargin{k}) || isstring(varargin{k}) || iscell(varargin{k}) || isstruct(varargin{k})
        has_char_opt = true;
        break;
    end
end

if numel(varargin) < 2 || has_char_opt || n_out > 1 || any(cellfun(@(x) isequal(x, ReturnFn), C))
    [varargout{:}] = builtin('arrayfun', ReturnFn, varargin{:});
    return;
end

func_str = func2str(ReturnFn);

% 3. Check persistent vectorized registry, then base vfoptions.vectorizedarrayfunnames
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

if ~is_vectorized && evalin('base', 'exist(''vfoptions'', ''var'')')
    vfoptions_base = evalin('base', 'vfoptions');
    if isstruct(vfoptions_base) && isfield(vfoptions_base, 'vectorizedarrayfunnames')
        vn = vfoptions_base.vectorizedarrayfunnames;
        if ischar(vn), vn = {vn}; end
        for ii = 1:numel(vn)
            if ~isempty(vn{ii}) && ~isempty(strfind(func_str, vn{ii}))
                is_vectorized = true;
                break;
            end
        end
    end
end

% 4. Execute vectorized CPU fast-path (with singleton broadcast completion) or scalar fallback
if is_vectorized
    F = ReturnFn(varargin{:});

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
            F = repmat(F, full_sz ./ f_sz);
        end
    end
    varargout{1} = F;
else
    varargout{1} = arrayfun_expand(ReturnFn, varargin{:});
end


end
