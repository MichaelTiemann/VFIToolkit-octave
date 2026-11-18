function persistent_worker(worker_id, ram_dir)
% PERSISTENT_WORKER Headless Octave worker with atomic load retry & parent-PID watchdog.

master_pid = -1;
init_file  = sprintf('%s/vfi_worker_init.bin', ram_dir);

% Wait up to 10 seconds for the master process to create and write the init file
t_init = tic;
init_loaded = false;
while toc(t_init) < 10.0
    if exist(init_file, 'file')
        try
            S = load('-binary', init_file);
            init_loaded = true;
            break;
        catch
            % File might still be actively written; brief pause and retry
            pause(0.005);
        end
    else
        pause(0.005);
    end
end

if init_loaded
    if isfield(S, 'master_pwd') && exist(S.master_pwd, 'dir')
        cd(S.master_pwd);
    end
    if isfield(S, 'master_path')
        path(S.master_path);
    end
    if isfield(S, 'master_pid')
        master_pid = S.master_pid;
    end
    if isfield(S, 'vec_names') && ~isempty(S.vec_names)
        vfi_vectorized_registry('set', S.vec_names);
    end
else
    warning('persistent_worker:init_timeout', 'Worker %d timed out waiting for init_file.', worker_id);
end

in_file    = sprintf('%s/vfi_worker_%d_in.bin', ram_dir, worker_id);
out_file   = sprintf('%s/vfi_worker_%d_out.bin', ram_dir, worker_id);
temp_out   = sprintf('%s/vfi_worker_%d_temp.bin', ram_dir, worker_id);
ready_file = sprintf('%s/vfi_worker_%d_ready', ram_dir, worker_id);
exit_file  = sprintf('%s/vfi_worker_%d_exited', ram_dir, worker_id);

fclose(fopen(ready_file, 'w'));
idle_t  = tic;
watch_t = tic;

while true
    if exist(in_file, 'file')
        loaded_ok = false;
        for retry = 1:10
            try
                load('-binary', in_file, 'func', 'args', 'is_vectorized', 'num_outs');
                loaded_ok = true;
                break;
            catch
                pause(0.001);
            end
        end

        if loaded_ok
            if exist(in_file, 'file'); delete(in_file); end
            should_exit = process_task(func, args, is_vectorized, num_outs, out_file, temp_out, exit_file);
            if should_exit
                exit(0);
            end
        end
        idle_t  = tic;
        watch_t = tic;
    else
        % Self-terminate automatically within ~2s if parent master Octave process died/crashed!
        if master_pid > 0 && toc(watch_t) > 2.0
            if kill(master_pid, 0) ~= 0
                exit(0);
            end
            watch_t = tic;
        end

        if toc(idle_t) < 5.0
            pause(0.0005); % Stay hot (0.5 ms) across age transitions j = N_j:-1:1
        else
            pause(0.020);  % Deep idle only when VFI solve is genuinely finished
        end
    end
end

end

function should_exit = process_task(func, args, is_vectorized, num_outs, out_file, temp_out, exit_file)
should_exit = false;
try
    if ischar(func) && strcmp(func, 'EXIT')
        fclose(fopen(exit_file, 'w'));
        should_exit = true;
        return;
    end

    if ~exist('is_vectorized', 'var'), is_vectorized = false; end
    if ~exist('num_outs', 'var'), num_outs = 1; end

    result = cell(1, num_outs);
    if is_vectorized
        [result{:}] = feval(func, args{:});
    else
        [result{:}] = arrayfun_expand(func, args{:});
    end

    save('-binary', temp_out, 'result');
    rename(temp_out, out_file);
catch err
    result = struct('message', err.message);
    save('-binary', temp_out, 'result');
    rename(temp_out, out_file);
end
end
