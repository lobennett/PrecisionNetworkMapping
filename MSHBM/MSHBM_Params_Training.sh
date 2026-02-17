#!/bin/bash
#
#SBATCH -n 1
#SBATCH -N 1
#SBATCH -c 1
#SBATCH -p russpold,normal
#SBATCH --mem=100GB
#SBATCH -t 12:00:00
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

export CBIG_CODE_DIR=$codedir/MSHBM/lib/CBIG_CODE_sparse

matlab -nojvm -nodesktop -r "addpath(genpath('$codedir')); MSHBM_Params_Training('$sub_list','$numofnet','$outputdir','$codedir'); quit"
