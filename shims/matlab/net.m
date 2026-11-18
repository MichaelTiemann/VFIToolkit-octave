function pts = net(s, n)
% NET Generates n low-discrepancy quasi-random points in [0,1]^Dim (Halton/prime-radical sequence)
% for sobolset structs created by shims/sobolset.m.
if ~isstruct(s) || ~isfield(s, 'vfi_is_sobolset')
    error('net: expected sobolset struct as first argument');
end
primes_list = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71];
d = s.Dim;
pts = zeros(n, d);
for j = 1:d
    b = primes_list(mod(j - 1, numel(primes_list)) + 1);
    for i = 1:n
        idx = i + s.Skip;
        f = 1 / b;
        r = 0;
        while idx > 0
            r = r + f * mod(idx, b);
            idx = floor(idx / b);
            f = f / b;
        end
        pts(i, j) = r;
    end
end
end
