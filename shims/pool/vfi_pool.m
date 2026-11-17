function out = vfi_pool(action, ncores, ram_dir)
% VFI_POOL Manage persistent headless GNU Octave worker processes with PID tracking & orphan reaping.

persistent active_ncores active_ram_dir
if isempty(active_ncores);  active_ncores  = 0;  end
if isempty(active_ram_dir); active_ram_dir = ''; end

if nargin < 1 || isempty(action)
    action = 'status';
end

switch lower(action)
    case 'status'
        out = struct('active', active_ncores > 0, 'ncores', active_ncores, 'ram_dir', active_ram_dir);

    case 'ensure'
        if nargin < 2 || isempty(ncores); ncores = max(1, nproc() - 2); end
        if nargin < 3 || isempty(ram_dir); ram_dir = '/Volumes/VFI_RAMDisk'; end
        % Verify existing workers are actually alive before reusing pool
        if active_ncores == ncores && strcmp(active_ram_dir, ram_dir) && workers_alive(ram_dir, ncores)
            out = struct('active', true, 'ncores', active_ncores, 'ram_dir', active_ram_dir);
            return;
        end
        if active_ncores > 0 || has_orphan_workers()
            vfi_pool('stop');
        end
        out = vfi_pool('start', ncores, ram_dir);

    case 'start'
        if nargin < 2 || isempty(ncores); ncores = max(1, nproc() - 2); end
        if nargin < 3 || isempty(ram_dir); ram_dir = '/Volumes/VFI_RAMDisk'; end

        % Always reap any stale/orphan workers from crashed prior runs before spawning
        reap_os_workers(ram_dir);

        if ~exist(ram_dir, 'dir')
            mkdir(ram_dir);
        end

        master_pwd  = pwd();
        master_path = path();
        master_pid  = getpid();
        vec_names   = vfi_vectorized_registry('get');
        init_file   = sprintf('%s/vfi_worker_init.bin', ram_dir);
        save('-binary', init_file, 'master_pwd', 'master_path', 'master_pid', 'vec_names');

        fprintf('Starting %d persistent Octave workers on %s...\n', ncores, ram_dir);
        fflush(stdout);

        oct_bin = fullfile(matlabroot(), 'bin', 'octave-cli');
        if ~exist(oct_bin, 'file')
            oct_bin = 'octave-cli';
        end
        pool_dir = fileparts(mfilename('fullpath'));

        pids = zeros(ncores, 1);
        for w = 1:ncores
            cmd = sprintf('OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 "%s" --no-gui --no-history --quiet --eval "addpath(''%s''); persistent_worker(%d, ''%s'');" >/dev/null 2>&1 & echo $!', ...
                oct_bin, pool_dir, w, ram_dir);
            [~, pid_str] = system(cmd);
            pids(w) = str2double(strtrim(pid_str));
        end
        pid_file = sprintf('%s/vfi_worker_pids.txt', ram_dir);
        dlmwrite(pid_file, pids, '\n');

        % Wait up to 15s for all workers to signal ready
        t_wait = tic;
        n_ready = 0;
        ready_mask = false(ncores, 1);
        while n_ready < ncores && toc(t_wait) < 15.0
            for w = 1:ncores
                if ~ready_mask(w) && exist(sprintf('%s/vfi_worker_%d_ready', ram_dir, w), 'file')
                    ready_mask(w) = true;
                    n_ready = n_ready + 1;
                end
            end
            if n_ready < ncores; pause(0.01); end
        end

        if n_ready < ncores
            reap_os_workers(ram_dir);
            error('vfi_pool: timed out waiting for workers (%d/%d ready)', n_ready, ncores);
        end

        active_ncores  = ncores;
        active_ram_dir = ram_dir;
        out = struct('active', true, 'ncores', active_ncores, 'ram_dir', active_ram_dir);

    case 'stop'
        target_dir = active_ram_dir;
        if isempty(target_dir); target_dir = '/Volumes/VFI_RAMDisk'; end
        if active_ncores > 0
            fprintf('Shutting down %d workers...\n', active_ncores);
            fflush(stdout);
            func = 'EXIT'; args = {}; is_vectorized = true; num_outs = 1;
            for w = 1:active_ncores
                tmp_f = sprintf('%s/vfi_worker_%d_in_tmp.bin', target_dir, w);
                in_f  = sprintf('%s/vfi_worker_%d_in.bin', target_dir, w);
                try
                    save('-binary', tmp_f, 'func', 'args', 'is_vectorized', 'num_outs');
                    rename(tmp_f, in_f);
                catch
                end
            end
            pause(0.08);
        end
        reap_os_workers(target_dir);
        active_ncores  = 0;
        active_ram_dir = '';
        out = struct('active', false, 'ncores', 0, 'ram_dir', '');

    otherwise
        error('vfi_pool: unknown action "%s"', action);
end

end

function tf = has_orphan_workers()
[st, ~] = system('pgrep -f "persistent_worker\(" >/dev/null 2>&1');
tf = (st == 0);
end

function tf = workers_alive(ram_dir, ncores)
pid_file = sprintf('%s/vfi_worker_pids.txt', ram_dir);
if ~exist(pid_file, 'file')
    tf = false;
    return;
end
pids = dlmread(pid_file);
if numel(pids) ~= ncores
    tf = false;
    return;
end
tf = true;
for w = 1:ncores
    if pids(w) <= 0 || kill(pids(w), 0) ~= 0
        tf = false;
        return;
    end
end
end

function reap_os_workers(ram_dir)
% 1. Kill tracked PIDs if pid_file exists
pid_file = sprintf('%s/vfi_worker_pids.txt', ram_dir);
if exist(pid_file, 'file')
    try
        pids = dlmread(pid_file);
        for k = 1:numel(pids)
            if pids(k) > 0
                kill(pids(k), 15); % SIGTERM
            end
        end
    catch
    end
end
% 2. Sweep any remaining persistent_worker processes owned by current user
system('pkill -f "persistent_worker\(" >/dev/null 2>&1 || true');
pause(0.05);
system('pkill -9 -f "persistent_worker\(" >/dev/null 2>&1 || true');
if exist(ram_dir, 'dir')
    system(sprintf('rm -f "%s"/vfi_worker_* >/dev/null 2>&1 || true', ram_dir));
end
end
