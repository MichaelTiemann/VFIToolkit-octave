function val_i = extract_ptype_struct(S, name_i, idx_i, N_i)
% EXTRACT_PTYPE_STRUCT Unpack per-PType field or indexed parameter following VFI Toolkit rules.
if isstruct(S)
    if isfield(S, name_i)
        val_i = S.(name_i);
    else
        % Struct of sub-fields (e.g. vfoptions.experienceasset.HH_Rural or Params.w_reg.HH_Rural)
        val_i = struct();
        fnames = fieldnames(S);
        for k = 1:numel(fnames)
            fk = fnames{k};
            fv = S.(fk);
            if isstruct(fv)
                if isfield(fv, name_i)
                    val_i.(fk) = fv.(name_i);
                end
            elseif iscell(fv) && numel(fv) == N_i && ~strcmp(fk, 'PTypeWeights')
                val_i.(fk) = fv{idx_i};
            else
                val_i.(fk) = fv;
            end
        end
    end
else
    val_i = S;
end
end
