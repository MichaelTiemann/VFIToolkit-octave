function vfoptions = Default_VFOptions_FHorz(vfoptions)
% DEFAULT_VFOPTIONS_FHORZ Canonical vfoptions initialization contract matching ValueFnIter_Case1_FHorz.

if nargin < 1 || isempty(vfoptions)
    vfoptions = struct();
end

if ~isfield(vfoptions, 'verbose');                  vfoptions.verbose = 0; end
if ~isfield(vfoptions, 'divideandconquer');         vfoptions.divideandconquer = 0; end
if ~isfield(vfoptions, 'gridinterplayer')
    vfoptions.gridinterplayer = 0;
elseif vfoptions.gridinterplayer == 1 && ~isfield(vfoptions, 'ngridinterp')
    error('When using vfoptions.gridinterplayer=1 you must set vfoptions.ngridinterp');
end
if ~isfield(vfoptions, 'lowmemory');                vfoptions.lowmemory = 0; end
if ~isfield(vfoptions, 'incrementaltype');          vfoptions.incrementaltype = 0; end
if ~isfield(vfoptions, 'exoticpreferences');        vfoptions.exoticpreferences = 'None'; end
if ~isfield(vfoptions, 'dynasty');                  vfoptions.dynasty = 0; end
if ~isfield(vfoptions, 'experienceasset');          vfoptions.experienceasset = 0; end
if ~isfield(vfoptions, 'experienceassetu');         vfoptions.experienceassetu = 0; end
if ~isfield(vfoptions, 'experienceassete');         vfoptions.experienceassete = 0; end
if ~isfield(vfoptions, 'experienceassetz');         vfoptions.experienceassetz = 0; end
if ~isfield(vfoptions, 'experienceassetze');        vfoptions.experienceassetze = 0; end
if ~isfield(vfoptions, 'experienceassetsemiz');     vfoptions.experienceassetsemiz = 0; end
if ~isfield(vfoptions, 'riskyasset');               vfoptions.riskyasset = 0; end
if ~isfield(vfoptions, 'residualasset');            vfoptions.residualasset = 0; end
if ~isfield(vfoptions, 'n_ambiguity');              vfoptions.n_ambiguity = 0; end
if ~isfield(vfoptions, 'n_e');                      vfoptions.n_e = 0; end
if ~isfield(vfoptions, 'n_semiz');                  vfoptions.n_semiz = 0; end
if ~isfield(vfoptions, 'parallel');                 vfoptions.parallel = 1 + (gpuDeviceCount > 0); end
if ~isfield(vfoptions, 'outputkron');               vfoptions.outputkron = 0; end
if ~isfield(vfoptions, 'alreadygridvals');          vfoptions.alreadygridvals = 0; end
if ~isfield(vfoptions, 'alreadygridvals_semiexo');  vfoptions.alreadygridvals_semiexo = 0; end

end
