function exportgraphics(fig_handle, filename, varargin)
% EXPORTGRAPHICS Octave compatibility shim mapping MATLAB exportgraphics() to print().
dpi = 300;
for k = 1:(numel(varargin) - 1)
    if ischar(varargin{k}) && strcmpi(varargin{k}, 'Resolution')
        dpi = varargin{k + 1};
    end
end
[~, ~, ext] = fileparts(filename);
if strcmpi(ext, '.pdf')
    dev = '-dpdf';
else
    dev = '-dpng';
end
print(fig_handle, filename, dev, sprintf('-r%d', dpi));
end
