function y = round(x, n, mode_str)
% ROUND Octave compatibility shim supporting MATLAB round(X, N) and round(X, N, 'significant').
if nargin == 1
    y = builtin('round', x);
    return;
end

if nargin >= 3 && ischar(mode_str) && strncmpi(mode_str, 'sig', 3)
    y = zeros(size(x), class(x));
    nz = (x ~= 0) & isfinite(x);
    if any(nz(:))
        mag = floor(log10(abs(double(x(nz)))));
        scale = 10 .^ (n - 1 - mag);
        y(nz) = builtin('round', double(x(nz)) .* scale) ./ scale;
    end
    y(~isfinite(x)) = x(~isfinite(x));
    return;
end

scale = 10 .^ n;
y = builtin('round', x .* scale) ./ scale;
end
