function out = vfi_vectorized_registry(action, names)
% VFI_VECTORIZED_REGISTRY Persistent registry of vectorized ReturnFn / aprimeFn names.
% Allows vectorized fast-path dispatch inside nested/PType callers (where 'base'
% workspace vfoptions may not exist or may be a per-PType struct).
%
% Usage:
%   vfi_vectorized_registry('add', {'ReturnFn_SpatialHH', 'ReturnFn_Firm'})
%   vfi_vectorized_registry('set', {'FORCE_VECTORIZED'})
%   vfi_vectorized_registry('clear')
%   names = vfi_vectorized_registry('get')

persistent reg_names
if isempty(reg_names)
    reg_names = {};
end

if nargin == 0 || strcmpi(action, 'get')
    out = reg_names;
    return;
end

if nargin < 2
    names = {};
elseif ischar(names)
    names = {names};
end

switch lower(action)
    case 'add'
        for k = 1:numel(names)
            if ~isempty(names{k}) && ~any(strcmp(reg_names, names{k}))
                reg_names{end+1} = names{k};
            end
        end
    case 'set'
        reg_names = names(:)';
    case 'clear'
        reg_names = {};
    otherwise
        error('vfi_vectorized_registry: unknown action "%s"', action);
end

out = reg_names;

end
