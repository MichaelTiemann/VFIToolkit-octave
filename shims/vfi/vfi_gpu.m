function y = vfi_gpu(x)
%VFI_GPU Move array to CUDA GPU when an active device is present; no-op on CPU/Octave.
if exist('OCTAVE_VERSION', 'builtin') == 0 ...
        && exist('gpuDeviceCount', 'file') ~= 0 && gpuDeviceCount > 0
    y = gpuArray(x);
else
    y = x;
end


end
