#!/bin/bash
#
#SBATCH -n 1
#SBATCH -N 1
#SBATCH -c 8
#SBATCH -p normal
#SBATCH --mem=96GB
#SBATCH -t 24:00:00
#SBATCH --job-name MSHBM_Training

# Sherlock modules
module load biology freesurfer/8.1.0
module load math matlab
module load workbench/1.3.1
module load biology fsl

sub_list=$1
numofnet=$2
outputdir=$3
codedir=$4

# Heavy external deps live outside the repo (relocated to $GROUP_HOME/sw; see
# setup_dependencies.sh). Resolve portably via env vars with $GROUP_HOME defaults.
export CBIG_CODE_DIR="${CBIG_CODE_DIR:-$GROUP_HOME/sw/CBIG}"
export CIFTI_MATLAB_DIR="${CIFTI_MATLAB_DIR:-$GROUP_HOME/sw/cifti-matlab}"

matlab -nojvm -nodesktop -r "addpath(genpath('$codedir')); MSHBM_Params_Training('$sub_list','$numofnet','$outputdir','$codedir'); quit"
