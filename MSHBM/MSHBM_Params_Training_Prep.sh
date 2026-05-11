#!/bin/bash
#
#SBATCH -n 1
#SBATCH -N 1
#SBATCH -p bigmem
#SBATCH --job-name MSHBM_Prep
#SBATCH --mem=256GB
#SBATCH -t 12:00:00

# Sherlock modules
module load biology freesurfer/8.1.0
module load math matlab
module load workbench/1.3.1
module load biology fsl

sub_list=$1
outputdir=$2
codedir=$3

export CBIG_CODE_DIR=$codedir/MSHBM/lib/CBIG_CODE_sparse

mkdir -p $outputdir/log

matlab -nojvm -nodesktop -r "addpath(genpath('$codedir')); MSHBM_wrapper('$sub_list','$outputdir','$codedir'); quit" &&
sleep 0.1

sbatch -o ${outputdir}/log/MSHBM_Training_%j.out -e ${outputdir}/log/MSHBM_Training_%j.err $codedir/MSHBM/MSHBM_Params_Training.sh $sub_list 15 $outputdir $codedir
