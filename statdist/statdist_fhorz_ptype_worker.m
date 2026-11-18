function dist_out = statdist_fhorz_ptype_worker(jequaloneDist, AgeWeightParamNames, Policy, n_d, n_a, n_z, N_j, pi_z, Parameters, simoptions)
% STATDIST_FHORZ_PTYPE_WORKER Parallel permanent-type worker for StationaryDist_MixHorz_PType.
if isfield(simoptions, 'aprimeFn_str')
    simoptions.aprimeFn = str2func(simoptions.aprimeFn_str);
    simoptions = rmfield(simoptions, 'aprimeFn_str');
end
dist_out = StationaryDist_FHorz_Case1(jequaloneDist, AgeWeightParamNames, Policy, n_d, n_a, n_z, N_j, pi_z, Parameters, simoptions);


end
