function VFIToolkit_Octave_Setup(vectorized_fn_names, enable_ufhorz)
% VFITOOLKIT_OCTAVE_SETUP Prepend VFIToolkit-octave paths ahead of VFIToolkit-matlab.

if nargin < 2 || isempty(enable_ufhorz)
    enable_ufhorz = true;
end

root_dir = fileparts(mfilename('fullpath'));

if enable_ufhorz
    addpath(fullfile(root_dir, 'uinfhorz'),           '-begin');
    addpath(fullfile(root_dir, 'ufhorz', 'matrices'), '-begin');
    addpath(fullfile(root_dir, 'ufhorz', 'solvers'),  '-begin');
    addpath(fullfile(root_dir, 'ufhorz'),             '-begin');
end

if exist('OCTAVE_VERSION', 'builtin') ~= 0
    addpath(fullfile(root_dir, 'shims', 'pool'), '-begin');
    addpath(fullfile(root_dir, 'shims'),         '-begin');
    if nargin >= 1 && ~isempty(vectorized_fn_names)
        vfi_vectorized_registry('add', vectorized_fn_names);
    end
end

end
