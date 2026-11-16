function [v_list, p_list] = ufhorz_multi_task_worker(sub_jobs, worker_mode)
% UFHORZ_MULTI_TASK_WORKER Executes a batch of (region, z) tasks on a persistent worker.
if nargin < 2 || isempty(worker_mode)
    worker_mode = 'expasset';
end
K = numel(sub_jobs);
v_list = cell(1, K);
p_list = cell(1, K);
if strcmp(worker_mode, 'raw4d')
    for k = 1:K
        jb = sub_jobs{k};
        [v_list{k}, p_list{k}] = ufhorz_raw_chunk_worker(jb{:});
    end
else
    for k = 1:K
        jb = sub_jobs{k};
        [v_list{k}, p_list{k}] = ufhorz_expasset_chunk_worker(jb{:});
    end
end
end
