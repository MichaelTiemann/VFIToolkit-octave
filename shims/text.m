function varargout = text(varargin)
% TEXT Octave compatibility shim supporting categorical X/Y coordinates & string labels.

args = varargin;
ax_arg = {};
if ~isempty(args) && isscalar(args{1}) && isnumeric(args{1}) && ishandle(args{1}) && strcmp(get(args{1}, 'type'), 'axes')
    ax_arg = {vfi_active_ax(args{1})};
    args = args(2:end);
end

if numel(args) < 3
    if nargout > 0; varargout{1} = []; end
    return;
end

% Convert categorical X or Y coordinates to numeric indices
if isa(args{1}, 'categorical')
    args{1} = vfi_cat2num(args{1});
end
if isa(args{2}, 'categorical')
    args{2} = vfi_cat2num(args{2});
end

if isempty(args{1}) || isempty(args{2})
    if nargout > 0; varargout{1} = []; end
    return;
end

% Detect 2D vs 3D
if numel(args) >= 4 && isnumeric(args{3}) && ~ischar(args{3}) && ~iscell(args{3})
    str_pos = 4;
else
    str_pos = 3;
end

lbl = args{str_pos};
if exist('isstring', 'file') && isstring(lbl)
    lbl = cellstr(lbl);
elseif isa(lbl, 'categorical')
    lbl = cellstr(lbl);
elseif isnumeric(lbl)
    lbl = arrayfun(@(v) num2str(v), lbl, 'UniformOutput', false);
end
args{str_pos} = lbl;

if iscell(lbl) && numel(lbl) > 1
    args{1} = reshape(double(args{1}), 1, []);
    args{2} = reshape(double(args{2}), 1, []);
    args{str_pos} = reshape(lbl, 1, []);
else
    args{1} = double(args{1});
    args{2} = double(args{2});
end

% Strip MATLAB-only text properties unsupported by Octave (e.g., 'Interpreter','none' is fine, check 'Margin' works)
clean_nv = {};
k = str_pos + 1;
while k <= numel(args)
    if ischar(args{k}) && k < numel(args)
        pname = args{k};
        pval  = args{k+1};
        if strcmpi(pname, 'FontWeight') || strcmpi(pname, 'FontSize') || strcmpi(pname, 'Color') ...
                || strcmpi(pname, 'HorizontalAlignment') || strcmpi(pname, 'VerticalAlignment') ...
                || strcmpi(pname, 'BackgroundColor') || strcmpi(pname, 'EdgeColor') ...
                || strcmpi(pname, 'Margin') || strcmpi(pname, 'Rotation') || strcmpi(pname, 'Interpreter')
            clean_nv(end+1:end+2) = {pname, pval};
        end
        k = k + 2;
    else
        k = k + 1;
    end
end
call_args = [args(1:str_pos), clean_nv];

stock_fn = vfi_stock_fn('text');
if nargout > 0
    [varargout{1:nargout}] = stock_fn(ax_arg{:}, call_args{:});
else
    stock_fn(ax_arg{:}, call_args{:});
end

end
