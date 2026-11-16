function results = vfi_dispatch_chunks(worker_fn_name, worker_args_cell, ram_dir, num_outs)
% VFI_DISPATCH_CHUNKS Dispatch K pre-sliced worker payloads across K persistent workers.

K = numel(worker_args_cell);
func = worker_fn_name;
is_vectorized = true;

for c = 1:K
    args = worker_args_cell{c};
    temp_in = sprintf('%s/vfi_worker_%d_in_tmp.mat', ram_dir, c);
    in_file = sprintf('%s/vfi_worker_%d_in.mat', ram_dir, c);
    save('-v6', temp_in, 'func', 'args', 'is_vectorized', 'num_outs');
    rename(temp_in, in_file);
end

results = cell(K, num_outs);
done = false(K, 1);
n_done = 0;

while n_done < K
    for c = 1:K
        if ~done(c)
            out_file = sprintf('%s/vfi_worker_%d_out.mat', ram_dir, c);
            if exist(out_file, 'file')
                data = load(out_file, 'result');
                delete(out_file);
                if isstruct(data.result) && isfield(data.result, 'message')
                    error('Worker %d exception: %s', c, data.result.message);
                end
                for o = 1:num_outs
                    results{c, o} = data.result{o};
                end
                done(c) = true;
                n_done = n_done + 1;
            end
        end
    end
    if n_done < K
        pause(0.002);
    end
end

end
