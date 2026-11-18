function out = false(varargin)
idx = strcmp(varargin, 'gpuArray');
filtered_args = varargin(~idx);
out = builtin('false', filtered_args{:});
end
