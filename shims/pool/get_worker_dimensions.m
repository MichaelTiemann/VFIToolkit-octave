%% get_worker_dimensions.m
function [n_a2_worker, n_z_worker] = get_worker_dimensions(n_a2, n_z, n_proc)
% Always slice along whichever state dimension gives the finest load balance;
% only slice z when len_z >= n_proc AND (len_z >= len_a2).
len_a2 = prod(n_a2);
len_z  = prod(n_z);

if len_a2 > len_z && n_proc > len_z
    workers     = min(max(1, n_proc), len_a2);
    n_a2_worker = ceil(len_a2 / workers);
    n_z_worker  = len_z;
elseif len_z >= n_proc
    workers     = min(max(1, n_proc), len_z);
    n_a2_worker = len_a2;
    n_z_worker  = ceil(len_z / workers);
else
    % Both len_a2 and len_z are smaller than n_proc: pick the larger one
    if len_a2 >= len_z
        workers     = max(1, len_a2);
        n_a2_worker = 1;
        n_z_worker  = len_z;
    else
        workers     = max(1, len_z);
        n_a2_worker = len_a2;
        n_z_worker  = 1;
    end
end


end
