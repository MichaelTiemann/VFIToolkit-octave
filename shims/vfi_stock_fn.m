function fh = vfi_stock_fn(fn_name)
% VFI_STOCK_FN Resolve and cache a direct function handle to Octave's stock implementation
% by scanning path() directories (avoiding unimplemented which('-all') and rmpath/addpath).

persistent fn_cache
if isempty(fn_cache)
    fn_cache = struct();
end
if isfield(fn_cache, fn_name)
    fh = fn_cache.(fn_name);
    return;
end

shim_dir = fileparts(mfilename('fullpath'));
pool_dir = fullfile(shim_dir, 'pool');

% 1. Scan explicit load-path directories (covers Octave core scripts/plot/* AND Tablicious packages)
dirs = strsplit(path(), pathsep());
target_dir = '';
for k = 1:numel(dirs)
    d = dirs{k};
    if isempty(d) || strcmp(d, shim_dir) || strcmp(d, pool_dir)
        continue;
    end
    if exist(fullfile(d, [fn_name, '.m']), 'file') == 2 || exist(fullfile(d, [fn_name, '.oct']), 'file') == 3
        target_dir = d;
        break;
    end
end

% 2. If not an .m/.oct file on path(), check if it is a C++ builtin
if isempty(target_dir)
    if exist(fn_name, 'builtin') == 5
        fh = @(varargin) builtin(fn_name, varargin{:});
        fn_cache.(fn_name) = fh;
        return;
    end
    error('vfi_stock_fn: could not locate stock implementation of "%s" on path()', fn_name);
end

old_pwd = pwd();
unwind_protect
    cd(target_dir);
    fh = str2func(fn_name);
unwind_protect_cleanup
    cd(old_pwd);
end_unwind_protect

fn_cache.(fn_name) = fh;
end
