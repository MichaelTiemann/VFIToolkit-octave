function VFIToolkit_Octave_Setup(enable_ufhorz)
% VFITOOLKIT_OCTAVE_SETUP Prepend VFIToolkit-octave paths ahead of VFIToolkit-matlab.
% Call this *after* adding VFIToolkit-matlab to the path so that VFIToolkit-octave
% shadows GPU-only allocations and routes finite-horizon solvers through UFHorz.

if nargin < 1 || isempty(enable_ufhorz)
    enable_ufhorz = true;
end

root_dir = fileparts(mfilename('fullpath'));

if enable_ufhorz
    addpath(fullfile(root_dir, 'ufhorz', 'matrices'), '-begin');
    addpath(fullfile(root_dir, 'ufhorz', 'solvers'),  '-begin');
    addpath(fullfile(root_dir, 'ufhorz'),             '-begin');
end

if exist('OCTAVE_VERSION', 'builtin') ~= 0
    addpath(fullfile(root_dir, 'shims', 'pool'), '-begin');
    addpath(fullfile(root_dir, 'shims'),         '-begin');
end

end
