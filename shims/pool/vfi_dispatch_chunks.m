function results = vfi_dispatch_chunks(worker_fn_name, worker_args_cell, ram_dir, num_outs)
% VFI_DISPATCH_CHUNKS Atomic task dispatcher using temp file + atomic rename.

K = numel(worker_args_cell);
func = worker_fn_name;
is_vectorized = true;

for c = 1:K
    args = worker_args_cell{c};
    if ~isempty(args) && isa(args{1}, 'function_handle')
        args{1} = resolve_fn_name(args{1});
    end
    temp_in  = sprintf('%s/vfi_worker_%d_in_tmp.bin', ram_dir, c);
    in_file  = sprintf('%s/vfi_worker_%d_in.bin', ram_dir, c);
    out_file = sprintf('%s/vfi_worker_%d_out.bin', ram_dir, c);

    % Ensure any stale input/output files are cleared before dropping new task
    if ~isempty(stat(in_file));  delete(in_file);  end
    if ~isempty(stat(out_file)); delete(out_file); end

    save('-binary', temp_in, 'func', 'args', 'is_vectorized', 'num_outs');
    rename(temp_in, in_file);
end

results = cell(K, num_outs);
done = false(K, 1);
n_done = 0;

while n_done < K
    for c = 1:K
        if ~done(c)
            out_file = sprintf('%s/vfi_worker_%d_out.bin', ram_dir, c);
            if ~isempty(stat(out_file))
                loaded = false;
                try
                    data = load('-binary', out_file, 'result');
                    delete(out_file);
                    loaded = true;
                catch
                    % Retry next poll if file is still mid-rename
                end

                if loaded
                    % Propagate worker exceptions OUTSIDE try/catch so we never spin forever!
                    if isstruct(data.result) && isfield(data.result, 'message')
                        error('Worker %d exception: %s', c, data.result.message);
                    elseif isa(data.result, 'MException')
                        rethrow(data.result);
                    end

                    for o = 1:num_outs
                        results{c, o} = data.result{o};
                    end
                    done(c) = true;
                    n_done = n_done + 1;
                end
            end
        end
    end
    if n_done < K
        pause(0.0003);
    end
end


end
