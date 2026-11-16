function fn_name = resolve_fn_name(fh)
% RESOLVE_FN_NAME Extract underlying .m function name from an anonymous wrapper or handle
% so Octave workers never have to serialize function_handle objects into .mat files.

if ischar(fh)
    fn_name = fh;
    return;
end

s = strtrim(func2str(fh));
if s(1) ~= '@'
    fn_name = s;
    return;
end

% Match '@(x, y, ...) TargetFnName(x, y, ...)' -> 'TargetFnName'
tok = regexp(s, '^@\([^)]*\)\s*([A-Za-z][A-Za-z0-9_]*)\s*\(', 'tokens', 'once');
if ~isempty(tok)
    fn_name = tok{1};
else
    error('resolve_fn_name: cannot serialize general anonymous closure "%s"; wrap an .m file function.', s);
end

end
