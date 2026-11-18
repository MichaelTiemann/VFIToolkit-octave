function [V_ii, Policy_ii] = ptype_vfi_worker(is_fhorz, retfn_str, n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, pi_z, Parameters, DiscountFactorParamNames, vfoptions)
% VFI_PTYPE_SINGLE_WORKER Solves one complete InfHorz or lightweight FHorz PType in-cache on 1 worker.
ReturnFn = str2func(retfn_str);
fn_flds  = fieldnames(vfoptions);
for f = 1:numel(fn_flds)
    nm = fn_flds{f};
    if numel(nm) > 6 && strcmp(nm(end-5:end), '_fhstr')
        orig_nm = nm(1:end-6);
        vfoptions.(orig_nm) = str2func(vfoptions.(nm));
        vfoptions = rmfield(vfoptions, nm);
    end
end
if is_fhorz
    [V_ii, Policy_ii] = ValueFnIter_Case1_FHorz(n_d, n_a, n_z, N_j, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, [], vfoptions);
else
    [V_ii, Policy_ii] = ValueFnIter_InfHorz(n_d, n_a, n_z, d_grid, a_grid, z_grid, pi_z, ReturnFn, Parameters, DiscountFactorParamNames, [], vfoptions);
end


end
