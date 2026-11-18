function out = vfi_pool(action, ncores, ram_dir)
% VFI_POOL Manage persistent headless GNU Octave worker processes with PID tracking & orphan reaping.

persistent active_ncores active_ram_dir
if isempty(active_ncores);  active_ncores  = 0;  end
if isempty(active_ram_dir); active_ram_dir = ''; end

if nargin < 1 || isempty(action)
    action = 'status';
end

% Determine OS-appropriate default RAM directory (/dev/shm for Linux/WSL, /Volumes for macOS)
if ispc()
    default_ram_dir = fullfile(tempdir, 'VFI_RAMDisk');
elseif ismac()
    default_ram_dir = '/Volumes/VFI_RAMDisk';
else
    % Linux / WSL
    default_ram_dir = '/dev/shm/VFI_RAMDisk';
end

switch lower(action)
    case 'status'
        out = struct('active', active_ncores > 0, 'ncores', active_ncores, 'ram_dir', active_ram_dir);

    case 'ensure'
        phys_cpus = detect_physical_cpus();
        if nargin < 2 || isempty(ncores); ncores = numel(phys_cpus); end
        if nargin < 3 || isempty(ram_dir); ram_dir = default_ram_dir; end
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
        phys_cpus = detect_physical_cpus();
        if nargin < 2 || isempty(ncores); ncores = numel(phys_cpus); end
        if nargin < 3 || isempty(ram_dir); ram_dir = default_ram_dir; end

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

        % Warn if running from /mnt/c DrvFS where 32 workers hit 9P stat contention
        if strncmp(master_pwd, '/mnt/', 5)
            fprintf('  [vfi_pool note] Working dir is on WSL /mnt/ (9P); workers will set ignore_function_time_stamp("all") to avoid 9P stat stalls.\n');
            fflush(stdout);
        end

        pids = zeros(ncores, 1);
        for w = 1:ncores
            % Set threading variables for cross-platform support (Linux/OpenBLAS + macOS/Accelerate)
            log_file = sprintf('%s/worker_%d.log', ram_dir, w);
            if ~ismac() && ~ispc()
                % Pin worker w to unique physical core primary thread (avoids WSL2/Linux interleaved SMT pairs!)
                cpu_id = phys_cpus(mod(w - 1, numel(phys_cpus)) + 1);
                pin_prefix = sprintf('taskset -c %d ', cpu_id);
            else
                pin_prefix = '';
            end
            cmd = sprintf('OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 MKL_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 %s"%s" --no-gui --no-history --quiet --eval "ignore_function_time_stamp(''all''); addpath(''%s''); persistent_worker(%d, ''%s'');" >"%s" 2>&1 & echo $!', ...
                pin_prefix, oct_bin, pool_dir, w, ram_dir, log_file);
            [~, pid_str] = system(cmd);
            pids(w) = str2double(strtrim(pid_str));
        end
        pid_file = sprintf('%s/vfi_worker_pids.txt', ram_dir);
        dlmwrite(pid_file, pids, '\n');

        % Wait up to 180s for all workers to signal ready
        t_wait = tic;
        n_ready = 0;
        ready_mask = false(ncores, 1);
        while n_ready < ncores && toc(t_wait) < 180.0
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
        if isempty(target_dir); target_dir = default_ram_dir; end
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

function phys_cpus = detect_physical_cpus()
% Returns 0-based OS CPU IDs of unique physical cores (1 thread per physical core).
if ~ismac() && ~ispc()
    [st, out_str] = system('cat /sys/devices/system/cpu/cpu[0-9]*/topology/thread_siblings_list 2>/dev/null | cut -d"," -f1 | cut -d"-" -f1 | sort -nu');
    if st == 0 && ~isempty(strtrim(out_str))
        vals = sscanf(out_str, '%d');
        if ~isempty(vals)
            phys_cpus = vals(:)';
            return;
        end
    end
end
% Fallback if sysfs unavailable (macOS / Windows)
n_log = nproc();
phys_cpus = 0:(max(1, n_log - 2) - 1);
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
