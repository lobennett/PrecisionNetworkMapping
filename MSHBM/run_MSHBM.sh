# Inputs:
sub_list=$1
outputdir=$2
codedir=$3
mkdir -p $outputdir/log

# # prepare to train model parameters

sbatch -o ${outputdir}/log/MSHBM_%j.out -e ${outputdir}/log/MSHBM_%j.err $codedir/MSHBM/MSHBM_Params_Training_Prep.sh $sub_list $outputdir $codedir 