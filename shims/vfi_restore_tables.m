function val = vfi_restore_tables(val)
% VFI_RESTORE_TABLES Recursively reconstruct Tablicious table objects from Octave .mat structs.
if isstruct(val)
    if isscalar(val)
        % Tablicious top-level PascalCase layout: VariableValues, VariableNames, RowNames
        if isfield(val, 'VariableValues') && isfield(val, 'VariableNames') && iscell(val.VariableValues)
            cols   = val.VariableValues;
            vnames = cellstr(val.VariableNames);
            if isfield(val, 'RowNames') && ~isempty(val.RowNames)
                val = table(cols{:}, 'VariableNames', vnames, 'RowNames', cellstr(val.RowNames));
            else
                val = table(cols{:}, 'VariableNames', vnames);
            end
            return;
        end
        % Fallback camelCase layout: varValues, varNames, rowNames
        if isfield(val, 'varValues') && isfield(val, 'varNames') && iscell(val.varValues)
            cols   = val.varValues;
            vnames = cellstr(val.varNames);
            if isfield(val, 'rowNames') && ~isempty(val.rowNames)
                val = table(cols{:}, 'VariableNames', vnames, 'RowNames', cellstr(val.rowNames));
            else
                val = table(cols{:}, 'VariableNames', vnames);
            end
            return;
        end
    end

    fnames = fieldnames(val);
    for n = 1:numel(val)
        for k = 1:numel(fnames)
            fk = fnames{k};
            val(n).(fk) = vfi_restore_tables(val(n).(fk));
        end
    end
elseif iscell(val)
    for k = 1:numel(val)
        val{k} = vfi_restore_tables(val{k});
    end
end
end
