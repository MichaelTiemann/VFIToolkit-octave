function [V_i, Policy_i] = ptype_vfi_worker(is_fhorz, n_d_i, n_a_i, n_z_i, N_j_i, d_grid_i, a_grid_i, z_grid_i, pi_z_i, ReturnFn_name, Params_i, DiscountNames_i, vfopt_i)
ReturnFn_i = str2func(ReturnFn_name);
vfopt_i.in_worker = true;
if is_fhorz
    [V_i, Policy_i] = ValueFnIter_Case1_FHorz(n_d_i, n_a_i, n_z_i, N_j_i, d_grid_i, a_grid_i, z_grid_i, pi_z_i, ReturnFn_i, Params_i, DiscountNames_i, [], vfopt_i);
else
    [V_i, Policy_i] = ValueFnIter_InfHorz(n_d_i, n_a_i, n_z_i, d_grid_i, a_grid_i, z_grid_i, pi_z_i, ReturnFn_i, Params_i, DiscountNames_i, [], vfopt_i);
end
end
