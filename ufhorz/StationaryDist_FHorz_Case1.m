function StationaryDist = StationaryDist_FHorz_Case1(jequaloneDist, AgeWeightParamNames, Policy, n_d, n_a, n_z, N_j, pi_z, Parameters, simoptions)
% Route standard & experienceasset=1 FHorz stationary distributions through cached vectorized Tan sweep.
if exist('simoptions', 'var') == 0 || isempty(simoptions)
    simoptions = struct();
end
is_supported = (~isfield(simoptions, 'n_e') || prod(simoptions.n_e) == 0) ...
            && (~isfield(simoptions, 'n_semiz') || prod(simoptions.n_semiz) == 0) ...
            && (~isfield(simoptions, 'gridinterplayer') || simoptions.gridinterplayer == 0) ...
            && (~isfield(simoptions, 'riskyasset') || simoptions.riskyasset == 0) ...
            && (~isfield(simoptions, 'experienceasset') || simoptions.experienceasset == 0 || (simoptions.experienceasset == 1 && length(n_a) >= 2));

if is_supported
    StationaryDist = StationaryDist_FHorz_Fast(jequaloneDist, AgeWeightParamNames, Policy, n_d, n_a, n_z, N_j, pi_z, Parameters, simoptions);
else
    error('StationaryDist_FHorz_Case1: unsupported simoptions combination in VFIToolkit-octave fast path');
end
end
