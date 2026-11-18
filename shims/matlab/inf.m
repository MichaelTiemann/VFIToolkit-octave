function out = inf(varargin)
idx = strcmp(varargin, 'gpuArray');
filtered_args = varargin(~idx);
out = builtin('inf', filtered_args{:});
end
