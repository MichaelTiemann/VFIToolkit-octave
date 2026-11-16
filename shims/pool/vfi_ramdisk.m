function ram_dir = vfi_ramdisk(action, size_mb)
% VFI_RAMDISK Resolve or mount an in-memory scratch directory on macOS and Linux.
%
% Usage:
%   ram_dir = vfi_ramdisk()              % Mount (if needed on macOS) & return path
%   ram_dir = vfi_ramdisk('mount', 2048) % Mount 2 GB RAM disk at /Volumes/VFI_RAMDisk
%   vfi_ramdisk('unmount')               % Eject /Volumes/VFI_RAMDisk on macOS

if nargin < 1 || isempty(action)
    action = 'ensure';
end
if nargin < 2 || isempty(size_mb)
    size_mb = 2048; % Default 2 GB
end

vol_name = 'VFI_RAMDisk';
mac_path = fullfile('/Volumes', vol_name);

if strcmpi(action, 'unmount')
    if ismac() && exist(mac_path, 'dir') ~= 0
        [status, out] = system(sprintf('diskutil eject "%s"', mac_path));
        if status ~= 0
            warning('vfi_ramdisk: failed to eject %s: %s', mac_path, out);
        end
    end
    ram_dir = '';
    return;
end

% 1. Linux tmpfs (/dev/shm)
if exist('/dev/shm', 'dir') ~= 0
    ram_dir = fullfile('/dev/shm', sprintf('vfi_%s', getenv('USER')));
    if exist(ram_dir, 'dir') == 0
        mkdir(ram_dir);
    end
    return;
end

% 2. macOS HFS+ RAM disk (/Volumes/VFI_RAMDisk)
if ismac()
    if exist(mac_path, 'dir') == 0
        sectors = round(size_mb * 2048); % 512-byte sectors per MB = 2048
        cmd = sprintf('diskutil erasevolume HFS+ "%s" $(hdiutil attach -nomount ram://%d)', vol_name, sectors);
        [status, out] = system(cmd);
        if status ~= 0 || exist(mac_path, 'dir') == 0
            warning('vfi_ramdisk: could not mount macOS RAM disk (%s); falling back to tempdir.', strtrim(out));
            ram_dir = fullfile(tempdir(), 'vfi_pool');
            if exist(ram_dir, 'dir') == 0; mkdir(ram_dir); end
            return;
        end
    end
    ram_dir = mac_path;
    return;
end

% 3. Generic fallback
ram_dir = fullfile(tempdir(), 'vfi_pool');
if exist(ram_dir, 'dir') == 0
    mkdir(ram_dir);
end

end
