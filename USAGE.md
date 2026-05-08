# MSHBM Usage Guide (Sherlock HPC)

This guide covers how to run the 15-network MSHBM individual parcellation pipeline on Sherlock. See [docs/sherlock-adaptation.md](docs/sherlock-adaptation.md) for details on what changed from the original Harvard NCF setup.

## Prerequisites

1. **Surface data in fsaverage6 space**: Task-regressed residuals and/or rest BOLD projected to fsaverage6 as `.nii.gz` files. See the [network_glm vol2fsaverage docs](../docs/vol2fsaverage.md) for how to generate these.

2. **File naming**: The MSHBM wrapper globs for files matching:
   ```
   lh*nat_resid_bpss_fsaverage6_sm*.nii.gz
   rh*nat_resid_bpss_fsaverage6_sm*.nii.gz
   ```
   The `prepare_mshbm_inputs.py` script produces files in this format automatically.

3. **Subject list CSV**: A CSV file mapping subjects to their data directories:
   ```csv
   sub-s03,/scratch/users/logben/surface_inputs/
   sub-s10,/scratch/users/logben/surface_inputs/
   sub-s19,/scratch/users/logben/surface_inputs/
   sub-s29,/scratch/users/logben/surface_inputs/
   sub-s43,/scratch/users/logben/surface_inputs/
   ```
   Each row is `<subject_id>,<parent_directory>/`. The wrapper will look in `<parent_directory>/<subject_id>/` for the surface files.

   A pre-made list for the 5 discovery subjects is at `data/mshbm_sub_list.csv`.

## Quick Start

### Step 1: Generate fsaverage6 surface inputs

```bash
cd /home/users/logben/network_glm

./slurm/prepare_mshbm_inputs.sh \
    --subjects-file data/subs_validation.txt \
    --glm-dir /oak/stanford/groups/russpold/data/network_grant/discovery_BIDS_20250402/derivatives/network_glm_lev1_surface \
    --fmriprep-dir /oak/stanford/groups/russpold/data/network_grant/discovery_BIDS_20250402/derivatives/fmriprep_24.1.0rc2 \
    --rest-fmriprep-dir /oak/stanford/groups/russpold/data/network_grant/discovery_BIDS_20250402/derivatives/fmriprep_rest_freesurfer_8.1.0_24.1.0rc2 \
    --residuals-space surface \
    --verbose
```

Wait for all jobs to complete, then verify output:
```bash
for sub in sub-s03 sub-s10 sub-s19 sub-s29 sub-s43; do
    echo "$sub: $(ls /scratch/users/logben/surface_inputs/$sub/lh*.nii.gz | wc -l) lh files"
done
```

### Step 2: Launch MSHBM

```bash
cd /home/users/logben/network_glm

bash PrecisionNetworkMapping/MSHBM/run_MSHBM.sh \
    data/mshbm_sub_list.csv \
    /scratch/users/logben/mshbm_output \
    $(pwd)/PrecisionNetworkMapping
```

This submits two chained SLURM jobs:

| Job | Script | What it does | Time |
|-----|--------|-------------|------|
| 1. Prep | `MSHBM_Params_Training_Prep.sh` | Generate FC profiles, average profiles | 12h |
| 2. Training | `MSHBM_Params_Training.sh` | Estimate group priors, extract parcellations, convert to CIFTI | 12h |

Job 2 is automatically submitted after Job 1 completes.

### Step 3: Monitor

```bash
# Check job status
squeue -u $(whoami)

# Check logs
ls /scratch/users/logben/mshbm_output/log/
cat /scratch/users/logben/mshbm_output/log/MSHBM_*.out
```

## Pipeline Details

### What happens in Job 1 (MSHBM_wrapper.m)

1. Reads the subject list CSV
2. For each subject, globs `lh*nat_resid_bpss_fsaverage6_sm*.nii.gz` and `rh*` in their data directory
3. Creates text files listing the full path to each session's data
4. Calls `CBIG_MSHBM_generate_profiles('fsaverage3','fsaverage6',...)` for each subject/session
5. Builds profile lists for individual parcellation and training
6. Calls `CBIG_MSHBM_avg_profiles('fsaverage3','fsaverage6',...)`

### What happens in Job 2 (MSHBM_Params_Training.m)

1. Copies the folder structure for the 15-network model
2. Loads the pre-trained DU15NET group prior (`MSHBM_prior_15.mat`)
3. Initializes MSHBM parameters via `CBIG_IndCBM_generate_MSHBM_params`
4. Estimates group priors via `CBIG_MSHBM_estimate_group_priors` (5 iterations)
5. Extracts individual parcellations via `CBIG_IndCBM_extract_MSHBM_result_SUB`
6. Converts labels to CIFTI format via `label2cifti`

### Output structure

```
/scratch/users/logben/mshbm_output/
  log/
    MSHBM_<jobid>.out
    MSHBM_Training_<jobid>.out
  Params_subs03s10s19s29s43/
    Params_training/
      generate_profiles_and_ini_params/
        data_list/fMRI_list/          # Text files with input paths
        profiles/                     # Per-subject FC profiles
          sub1/sess1/                 # lh/rh profile .nii.gz files
          avg_profile/                # Averaged profiles
        group/group.mat               # Group labels
      estimate_group_priors/
        priors/Params_Final.mat       # Trained model parameters
        group/group.mat
      generate_individual_parcellations/
        profile_list/test_set/        # Profile text files
    Params_training_15/
      estimate_group_priors/
        ind_parcellation/             # Individual parcellation .mat files
          Ind_parcellation_MSHBM_sub1_sub-s03.mat
          sub-s03/
            sub-s03_MSHBM.dscalar.nii
            sub-s03_MSHBM.dlabel.nii
            sub-s03_MSHBM_lh.label.gii
            sub-s03_MSHBM_rh.label.gii
            sub-s03_MSHBM_lh.border
            sub-s03_MSHBM_rh.border
          ...
```

## Adding New Subjects

1. Run Level 1 GLM with residuals in surface space:
   ```bash
   ./slurm/lev1_batch.sh \
       --subjects-file data/new_subjects.txt \
       --tasks --base-tasks \
       --bids-dir /path/to/bids \
       --fmriprep-dir /path/to/fmriprep \
       --output-dir /path/to/lev1_surface \
       --exclusions-file ./data/exclusions.json \
       --space surface --residuals
   ```

2. Prepare fsaverage6 surface inputs:
   ```bash
   ./slurm/prepare_mshbm_inputs.sh \
       --subjects-file data/new_subjects.txt \
       --glm-dir /path/to/lev1_surface \
       --fmriprep-dir /path/to/fmriprep \
       --rest-fmriprep-dir /path/to/rest_fmriprep \
       --residuals-space surface
   ```

3. Update `data/mshbm_sub_list.csv` with new subject rows

4. Re-run MSHBM:
   ```bash
   bash PrecisionNetworkMapping/MSHBM/run_MSHBM.sh \
       data/mshbm_sub_list.csv \
       /scratch/users/logben/mshbm_output \
       $(pwd)/PrecisionNetworkMapping
   ```

## Troubleshooting

### MATLAB can't find MRIread/MRIwrite

The FreeSurfer MATLAB toolbox is symlinked into `MSHBM/lib/freesurfer/matlab/`. Verify the symlinks are intact:
```bash
ls -la PrecisionNetworkMapping/MSHBM/lib/freesurfer/matlab/MRIread.m
```
If broken, re-create:
```bash
ln -sf /share/software/user/open/freesurfer/8.1.0/matlab/*.m \
    PrecisionNetworkMapping/MSHBM/lib/freesurfer/matlab/
```

### CBIG_CODE_DIR errors

The CBIG code is at `MSHBM/lib/CBIG_CODE_sparse/`. Verify the environment variable is set correctly in the SLURM scripts:
```bash
grep CBIG_CODE_DIR PrecisionNetworkMapping/MSHBM/MSHBM_Params_Training_Prep.sh
# Should show: export CBIG_CODE_DIR=$codedir/MSHBM/lib/CBIG_CODE_sparse
```

### ciftiopen/ciftisavereset not found

These come from the cifti-matlab toolbox at `MSHBM/lib/cifti-matlab/`. If missing:
```bash
git clone https://github.com/Washington-University/cifti-matlab \
    PrecisionNetworkMapping/MSHBM/lib/cifti-matlab
```

### No surface input files found

Check that `prepare_mshbm_inputs.py` produced files matching the expected glob pattern:
```bash
ls /scratch/users/logben/surface_inputs/sub-s03/lh*nat_resid_bpss_fsaverage6_sm*.nii.gz
```
Files should be named like `lh_ses-02_task-cuedTS_run-1_nat_resid_bpss_fsaverage6_sm0.nii.gz`.
