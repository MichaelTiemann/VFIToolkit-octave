function bins = discretize(x, edges)
% DISCRETIZE Octave compatibility shim for MATLAB's 2-argument discretize(X, EDGES).
% Places elements of X into bins defined by monotonically non-decreasing EDGES:
%   edges(k) <= X(i) < edges(k+1)  for k = 1 : length(edges)-2
%   edges(N-1) <= X(i) <= edges(N) for the final bin k = N-1
% Out-of-range values and NaNs return NaN.

if nargin < 2
    error('discretize: requires at least X and EDGES arguments');
end

edges_col = edges(:);
n_edges = numel(edges_col);
if n_edges < 2
    error('discretize: EDGES must contain at least two elements');
end

bins = lookup(edges_col, x);
out_of_bounds = isnan(x) | (x < edges_col(1)) | (x > edges_col(end));
bins(x == edges_col(end)) = n_edges - 1;
bins(out_of_bounds) = NaN;

end
