# Sherlock HPC Adaptation

This document tracks all changes made to adapt the PrecisionNetworkMapping pipeline from the Harvard NCF cluster to Stanford's Sherlock HPC.

## Module Replacements

| Component | Harvard NCF | Sherlock |
|-----------|------------|---------|
| FreeSurfer | `module load ncf/1.0.0-fasrc01; module load freesurfer/6.0.0-ncf` | `module load biology freesurfer/8.1.0` |
| MATLAB | `module load matlab/R2019b-fasrc01-ncf` | `module load math matlab` (R2024a) |
| Workbench | `module load connectome_workbench/1.3.2-centos6_x64-ncf` | `module load workbench/1.3.1` |
| FSL | `module load fsl/5.0.4-ncf` | `module load biology fsl` |
| SLURM partition | `-p cnl` | `-p russpold,normal` |

## File Changes

### MSHBM/MSHBM_Params_Training_Prep.sh

- Replaced NCF modules with Sherlock equivalents (see table above)
- Changed partition from `cnl` to `russpold,normal`
- Changed `CBIG_CODE_DIR` from `$codedir/ncf_tools/CBIG_CODE` to `$codedir/MSHBM/lib/CBIG_CODE_sparse`
- Moved `sub_list`, `outputdir`, `codedir` variable assignments below module loads (the NCF original had `CBIG_CODE_DIR` set before variable assignments)
- Added `mkdir -p $outputdir/log` before MATLAB call

### MSHBM/MSHBM_Params_Training.sh

- Same module and partition replacements as Prep script
- Same `CBIG_CODE_DIR` path update

### MSHBM/label2cifti.m

- Replaced hardcoded Harvard Workbench path (`codedir/ncf_tools/connectome-workbench/1.3.2-fasrc01/bin_rh_linux64/wb_command`) with `wb_command` (from PATH via `module load workbench/1.3.1`)
- Replaced hardcoded fsaverage6 surface paths (`codedir/ncf_tools/fsaverage6/surf/...`) with `$FREESURFER_HOME/subjects/fsaverage6/surf/...` (from `getenv('FREESURFER_HOME')`)
- Removed `system('module load wb_contain/1.0.0-linux_x64-ncf')` call (module is loaded in the SLURM script instead)
- Fixed trailing space in colorfile path

### MSHBM/run_MSHBM.sh

- Fixed variable name bug: `$output_dir` on line 5 changed to `$outputdir` (matching the actual variable assignment on line 2)

## Library Dependencies

The original pipeline required `ncf_tools/CBIG_CODE` (a full clone of the CBIG repo) and `ncf_tools/connectome-workbench`. On Sherlock, these are provided through modules and a sparse clone:

### MSHBM/lib/ directory structure

```
lib/
  CBIG_CODE_sparse/           # Sparse git clone of ThomasYeoLab/CBIG
    stable_projects/
      brain_parcellation/
        Kong2019_MSHBM/       # MSHBM steps 1-3
        Xue2021_IndCerebellum/  # CBIG_IndCBM_generate_MSHBM_params
    utilities/
      matlab/                 # CBIG MATLAB utilities
  cifti-matlab/               # Washington-University/cifti-matlab (ciftiopen, ciftisavereset)
  freesurfer/
    matlab/                   # Symlinks to $FREESURFER_HOME/matlab/*.m (MRIread, MRIwrite, etc.)
```

### Why a sparse clone?

The full CBIG repo is several GB and caused "No space left on device" errors. A sparse checkout of only the required directories keeps the footprint small. The 4 functions needed are:

| Function | Source | Used by |
|----------|--------|---------|
| `CBIG_MSHBM_generate_profiles` | Kong2019_MSHBM/step1 | MSHBM_wrapper.m |
| `CBIG_MSHBM_avg_profiles` | Kong2019_MSHBM/step1 | MSHBM_wrapper.m |
| `CBIG_IndCBM_generate_MSHBM_params` | Xue2021_IndCerebellum | MSHBM_Params_Training.m |
| `CBIG_MSHBM_estimate_group_priors` | Kong2019_MSHBM/step2 | MSHBM_Params_Training.m |

### FreeSurfer MATLAB toolbox

The CBIG functions use `MRIread`/`MRIwrite` from FreeSurfer's MATLAB toolbox. The original pipeline expected these in `lib/freesurfer/matlab/` (per `README_JD.md`). On Sherlock, we symlink from the module installation:

```
lib/freesurfer/matlab/ -> /share/software/user/open/freesurfer/8.1.0/matlab/*.m
```

This is picked up automatically by `addpath(genpath(codedir/MSHBM))` in the MATLAB scripts.

## Files Not Changed

| File | Reason |
|------|--------|
| `MSHBM_wrapper.m` | No cluster-specific paths; uses `codedir` argument |
| `MSHBM_Params_Training.m` | No cluster-specific paths; uses `codedir` argument |
| `CBIG_IndCBM_extract_MSHBM_result_SUB.m` | Pure MATLAB, no external dependencies |
| `MSHBM_prior_15.mat` | Data file, portable |
| `ColorMap_15.txt` | Data file, portable |
| `fsaverage6_cifti_template.dscalar.nii` | Data file, portable |
| `MSHBM_folder_structure_template/` | Directory structure, newly created |
