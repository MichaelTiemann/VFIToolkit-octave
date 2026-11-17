function h = gobjects(varargin)
% GOBJECTS Octave compatibility shim returning numeric NaN handle array.
if nargin == 0; h = NaN; elseif nargin == 1 && isscalar(varargin{1}); h = nan(varargin{1}); else; h = nan(varargin{:}); end
end
