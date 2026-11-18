function s = sobolset(dim, varargin)
% SOBOLSET Lightweight Octave compatibility struct for MATLAB sobolset(dim, 'Skip', k).
skip = 0;
for k = 1:2:(numel(varargin) - 1)
    if ischar(varargin{k}) && strcmpi(varargin{k}, 'Skip')
        skip = varargin{k + 1};
    end
end
s = struct('vfi_is_sobolset', true, 'Dim', dim, 'Skip', skip);
end
