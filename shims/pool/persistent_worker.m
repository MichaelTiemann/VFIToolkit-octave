function persistent_worker(worker_id, ram_dir)
% PERSISTENT_WORKER Headless Octave worker process backed by RAM-disk binary IPC.

init_file  = sprintf('%s/vfi_worker_init.bin', ram_dir);
if exist(init_file, 'file')
    S = load('-binary', init_file);
    if isfield(S, 'master_pwd') && exist(S.master_pwd, 'dir')
        cd(S.master_pwd);
    end
    if isfield(S, 'master_path')
        path(S.master_path);
    end
    if isfield(S, 'vec_names') && ~isempty(S.vec_names)
        vfi_vectorized_registry('set', S.vec_names);
    end
end

in_file    = sprintf('%s/vfi_worker_%d_in.bin', ram_dir, worker_id);
out_file   = sprintf('%s/vfi_worker_%d_out.bin', ram_dir, worker_id);
temp_out   = sprintf('%s/vfi_worker_%d_temp.bin', ram_dir, worker_id);
ready_file = sprintf('%s/vfi_worker_%d_ready', ram_dir, worker_id);
exit_file  = sprintf('%s/vfi_worker_%d_exited', ram_dir, worker_id);

fclose(fopen(ready_file, 'w'));

while true
    if exist(in_file, 'file')
        should_exit = process_task(in_file, out_file, temp_out, exit_file);
        if should_exit
            exit(0);
        end
    else
        pause(0.001);
    end
end

end

function should_exit = process_task(in_file, out_file, temp_out, exit_file)
should_exit = false;
try
    load('-binary', in_file, 'func', 'args', 'is_vectorized', 'num_outs');
    delete(in_file);

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
    if exist(in_file, 'file')
        delete(in_file);
    end
    result = struct('message', err.message);
    save('-binary', temp_out, 'result');
    rename(temp_out, out_file);
end
end
