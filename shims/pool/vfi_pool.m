function state = vfi_pool(action, ncores, ram_dir)
% VFI_POOL Manage persistent headless GNU Octave workers backed by RAM disk.

persistent active_ncores active_ram_dir
if isempty(active_ncores); active_ncores = 0; end
if isempty(active_ram_dir); active_ram_dir = ''; end

if nargin < 1 || strcmpi(action, 'status')
    state = struct('ncores', active_ncores, 'ram_dir', active_ram_dir, 'active', active_ncores > 0);
    return;
end

if nargin < 2 || isempty(ncores)
    if active_ncores > 0
        ncores = active_ncores;
    else
        ncores = max(1, nproc() - 2);
    end
end
if nargin < 3 || isempty(ram_dir)
    if ~isempty(active_ram_dir)
        ram_dir = active_ram_dir;
    else
        ram_dir = vfi_ramdisk();
    end
end

switch lower(action)
    case 'ensure'
        if active_ncores == ncores && strcmp(active_ram_dir, ram_dir)
            state = struct('ncores', active_ncores, 'ram_dir', active_ram_dir, 'active', true);
            return;
        elseif active_ncores > 0
            vfi_pool('stop', active_ncores, active_ram_dir);
        end
        state = vfi_pool('start', ncores, ram_dir);

    case 'stop'
        if ncores <= 0; return; end
        fprintf('Shutting down %d workers...\n', ncores);
        for i = 1:ncores
            func = 'EXIT';
            args = {};
            is_vectorized = false;
            num_outs = 1;
            temp_in = sprintf('%s/vfi_worker_%d_in_tmp.bin', ram_dir, i);
            in_file = sprintf('%s/vfi_worker_%d_in.bin', ram_dir, i);
            save('-binary', temp_in, 'func', 'args', 'is_vectorized', 'num_outs');
            rename(temp_in, in_file);
        end
        t_wait = tic;
        for i = 1:ncores
            exit_file = sprintf('%s/vfi_worker_%d_exited', ram_dir, i);
            while ~exist(exit_file, 'file') && toc(t_wait) < 5.0
                pause(0.002);
            end
            if exist(exit_file, 'file'); delete(exit_file); end
        end
        system('pkill -f "persistent_worker(" >/dev/null 2>&1 || true');
        system(sprintf('rm -f "%s"/vfi_worker_*', ram_dir));
        active_ncores = 0;
        active_ram_dir = '';
        state = struct('ncores', 0, 'ram_dir', '', 'active', false);

    case 'start'
        fprintf('Starting %d persistent Octave workers on %s...\n', ncores, ram_dir);
        system('pkill -f "persistent_worker(" >/dev/null 2>&1 || true');
        system(sprintf('rm -f "%s"/vfi_worker_*', ram_dir));

        master_path = path();
        master_pwd  = pwd();
        vec_names   = vfi_vectorized_registry('get');
        pool_dir    = fileparts(mfilename('fullpath'));
        init_file   = sprintf('%s/vfi_worker_init.bin', ram_dir);
        save('-binary', init_file, 'master_path', 'master_pwd', 'vec_names');

        for i = 1:ncores
            cmd = sprintf( ...
                'OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 octave-cli --no-gui --no-window-system --eval "addpath(''%s''); persistent_worker(%d, ''%s'')" >/dev/null 2>&1 &', ...
                pool_dir, i, ram_dir);
            system(cmd);
        end

        for i = 1:ncores
            ready_file = sprintf('%s/vfi_worker_%d_ready', ram_dir, i);
            while ~exist(ready_file, 'file')
                pause(0.002);
            end
            delete(ready_file);
        end
        active_ncores  = ncores;
        active_ram_dir = ram_dir;
        state = struct('ncores', active_ncores, 'ram_dir', active_ram_dir, 'active', true);

    case 'restart'
        if active_ncores > 0
            vfi_pool('stop', active_ncores, active_ram_dir);
        end
        state = vfi_pool('start', ncores, ram_dir);
end

end
