function out = true(varargin)
idx = strcmp(varargin, 'gpuArray');
filtered_args = varargin(~idx);
out = builtin('true', filtered_args{:});
end
