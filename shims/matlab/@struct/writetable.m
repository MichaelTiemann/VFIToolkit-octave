function writetable(S, filename, varargin)
% @STRUCT/WRITETABLE Automatically reconstruct Tablicious table from Octave .mat struct and dispatch to @table/writetable.
T = vfi_restore_tables(S);
if isstruct(T)
    error('writetable: input struct does not match Tablicious table layout');
end
writetable(T, filename, varargin{:});
end
