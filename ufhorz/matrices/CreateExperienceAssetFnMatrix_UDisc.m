function [a2primeIndexes, a2primeProbs] = CreateExperienceAssetFnMatrix_UDisc(aprimeFn, n_d, n_a2, d_gridvals, a2_grid, aprimeFnParams, aprimeIndexAsColumn, varargin)
% Universal Experience Asset Matrix Builder for the UDisc (Unified Discrete) Architecture.
% Supports both single experience asset (l_a2 == 1) and two experience assets (l_a2 == 2, with2A2).

% 1. Parameter Setup
ParamCell = num2cell(aprimeFnParams)';

N_d  = max(prod(n_d), 1);
N_a2 = max(prod(n_a2), 1);
l_d  = size(d_gridvals, 2);
l_a2 = length(n_a2);

d_Cells = {};
if N_d > 1 || l_d > 0
    for i = 1:l_d
        d_Cells{end+1} = d_gridvals(:, i);
    end
end

if l_a2 == 1
    % --- SINGLE EXPERIENCE ASSET (l_a2 == 1) ---
    GridParamsCell = d_Cells;
    GridParamsCell{end+1} = shiftdim(a2_grid(:), -1); % Dim 2: a2

    dim_offset = 2;
    state_dims = [];
    for v = 1:2:length(varargin)
        n_x = varargin{v};
        x_gridvals = varargin{v+1};
        N_x = max(prod(n_x), 1);
        state_dims = [state_dims, N_x];
        l_x = size(x_gridvals, 2);
        for i = 1:l_x
            GridParamsCell{end+1} = shiftdim(x_gridvals(:, i), -dim_offset);
        end
        dim_offset = dim_offset + 1;
    end
    if isempty(state_dims); state_dims = 1; end

    a2primeVals = vfi_arrayfun(aprimeFn, GridParamsCell{:}, ParamCell{:});
    [a2primeIndexes, a2primeProbs] = interp_1d_local(a2primeVals(:), a2_grid(:));

    if aprimeIndexAsColumn == 1
        % Returned flat as [N_d * N_a2 * states, 1]
    elseif aprimeIndexAsColumn == 2
        out_sz = [N_d, N_a2, state_dims];
        if length(out_sz) == 2; out_sz = [out_sz, 1]; end
        a2primeIndexes = reshape(a2primeIndexes, out_sz);
        a2primeProbs   = reshape(a2primeProbs, out_sz);
    elseif aprimeIndexAsColumn == 3
        out_sz = [N_d * N_a2, state_dims];
        if length(out_sz) == 1; out_sz = [out_sz, 1]; end
        a2primeIndexes = reshape(a2primeIndexes, out_sz);
        a2primeProbs   = reshape(a2primeProbs, out_sz);
    end

elseif l_a2 == 2
    % --- TWO EXPERIENCE ASSETS (l_a2 == 2, with2A2) ---
    n_a2_1    = n_a2(1);
    n_a2_2    = n_a2(2);
    a2_grid_1 = a2_grid(1:n_a2_1);
    a2_grid_2 = a2_grid(n_a2_1+1:n_a2_1+n_a2_2);

    GridParamsCell = d_Cells;
    GridParamsCell{end+1} = shiftdim(a2_grid_1(:), -1); % Dim 2: a2_1 (h)
    GridParamsCell{end+1} = shiftdim(a2_grid_2(:), -2); % Dim 3: a2_2 (theta_c)

    dim_offset = 3;
    state_dims = [];
    exog_Cells = {};
    for v = 1:2:length(varargin)
        n_x = varargin{v};
        x_gridvals = varargin{v+1};
        N_x = max(prod(n_x), 1);
        state_dims = [state_dims, N_x];
        l_x = size(x_gridvals, 2);
        for i = 1:l_x
            exog_Cells{end+1} = shiftdim(x_gridvals(:, i), -dim_offset);
        end
        dim_offset = dim_offset + 1;
    end
    if isempty(state_dims); state_dims = 1; end

    % Evaluate aprimeFn for each experience asset dimension using whicha = 1 and whicha = 2
    a2primeVals_1 = vfi_arrayfun(aprimeFn, GridParamsCell{:}, 1, exog_Cells{:}, ParamCell{:});
    a2primeVals_2 = vfi_arrayfun(aprimeFn, GridParamsCell{:}, 2, exog_Cells{:}, ParamCell{:});

    [idx_1, prob_1] = interp_1d_local(a2primeVals_1(:), a2_grid_1(:));
    [idx_2, prob_2] = interp_1d_local(a2primeVals_2(:), a2_grid_2(:));

    % Stack per-dimension factored indices and probabilities along leading row (1 = a2_1, 2 = a2_2)
    N_tot = numel(idx_1);
    a2primeIndexes = [reshape(idx_1,  1, N_tot); reshape(idx_2,  1, N_tot)];
    a2primeProbs   = [reshape(prob_1, 1, N_tot); reshape(prob_2, 1, N_tot)];

    if aprimeIndexAsColumn == 1
        % Keep [2, N_d * N_a2 * states] for Indexes, reshape Probs to [2, N_d, N_a2, state_dims]
        out_sz = [2, N_d, N_a2, state_dims];
        a2primeProbs = reshape(a2primeProbs, out_sz);
    elseif aprimeIndexAsColumn == 2
        out_sz = [2, N_d, N_a2, state_dims];
        a2primeIndexes = reshape(a2primeIndexes, out_sz);
        a2primeProbs   = reshape(a2primeProbs, out_sz);
    elseif aprimeIndexAsColumn == 3
        out_sz = [2, N_d * N_a2, state_dims];
        a2primeIndexes = reshape(a2primeIndexes, out_sz);
        a2primeProbs   = reshape(a2primeProbs, out_sz);
    end
else
    error('CreateExperienceAssetFnMatrix_UDisc supports length(n_a2) in {1, 2}');
end

end

function [a2primeIndexes, a2primeProbs] = interp_1d_local(a2primeVals, a2_grid)
total_elements = numel(a2primeVals);
a2_griddiff    = a2_grid(2:end) - a2_grid(1:end-1);
a2_grid_col    = a2_grid(:)';

if total_elements * length(a2_grid) < 10000000
    [~, a2primeIndexes] = max((a2_grid_col > a2primeVals), [], 2);
    a2primeIndexes = a2primeIndexes - 1;
    a2primeIndexes(a2primeIndexes == 0) = 1;
else
    a2primeIndexes = discretize(a2primeVals, a2_grid);
    a2primeIndexes(isnan(a2primeIndexes)) = 1;
end

offTopOfGrid = (a2primeVals >= a2_grid(end));
a2primeIndexes(offTopOfGrid) = length(a2_grid) - 1;

offBottomOfGrid = (a2primeVals <= a2_grid(1));
a2primeIndexes(offBottomOfGrid) = 1;

aprime_residual = a2primeVals - a2_grid(a2primeIndexes);
a2primeProbs    = 1 - aprime_residual ./ a2_griddiff(a2primeIndexes);

a2primeProbs(offBottomOfGrid) = 1;
a2primeProbs(offTopOfGrid)    = 0;


end
