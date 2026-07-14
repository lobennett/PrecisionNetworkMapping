function MSHBM_Params_Training(sub_list,numofnet,output_dir,codedir)

% MSHBM_Params_Training - Train MSHBM parameters and extract network assignments
% Written by Jingnan Du and Noam Saadon-Grosman
% Contact Jingnan Du at jingnandu@fas.harvard.edu if you have any questions


addpath(genpath(fullfile([codedir '/MSHBM'])))
% addpath(genpath(fullfile([codedir '/ncf_tools'])))

% Heavy external MATLAB deps are relocated out of the repo (see
% setup_dependencies.sh / README). Resolve them from env vars, defaulting to
% $GROUP_HOME/sw so a fresh checkout works without machine-hardcoded paths.
cbig_dir = getenv('CBIG_CODE_DIR');
if isempty(cbig_dir), cbig_dir = fullfile(getenv('GROUP_HOME'),'sw','CBIG'); end
addpath(genpath(cbig_dir));
cifti_dir = getenv('CIFTI_MATLAB_DIR');
if isempty(cifti_dir), cifti_dir = fullfile(getenv('GROUP_HOME'),'sw','cifti-matlab'); end
addpath(genpath(cifti_dir));
fs_home = getenv('FREESURFER_HOME');
if ~isempty(fs_home), addpath(fullfile(fs_home,'matlab')); end

numofnet=str2double(numofnet);
sub_list_table=readtable(sub_list,'Delimiter',',','ReadVariableNames',false);
SUB=(table2cell(sub_list_table(:,1)))';
partition=(table2cell(sub_list_table(:,2)))';
% construct output folder name from full subject IDs (BIDS-compliant).
% For large cohorts, fall back to count-based name to avoid 255-byte path limit.
SUBin = strjoin(SUB, '_');
if length(SUBin) > 200
    SUBin = ['cohort_N' num2str(length(SUB))];
end

for s=1:length(SUB)

    datadir=partition{s};
    cd(fullfile([datadir SUB{s}]))
    % Accept either the original prep-mshbm naming
    %   lh_ses-NN_task-T_run-1_nat_resid_bpss_fsaverage6_sm0.nii.gz
    % or the XCP-D-based naming
    %   lh_ses-NN_task-T_xcpd_fsaverage6_sm2.nii.gz
    % by matching the common fsaverage6_sm* suffix only.
    lhdirlist = dir('lh*fsaverage6_sm*.nii.gz');
    rhdirlist = dir('rh*fsaverage6_sm*.nii.gz');
    % If MSHBM_wrapper grouped files by BIDS recording session
    % (MSHBM_GROUP_BY_SESSION=1), the # of MSHBM sessions equals the # of
    % unique ses-NN tags, not the # of scan files. Mirror that counting
    % logic here so num_sess passed to CBIG_MSHBM_estimate_group_priors
    % matches the actual profile_list/training_set/lh_sess?.txt count.
    if strcmp(getenv('MSHBM_GROUP_BY_SESSION'), '1')
        sess_ids = {};
        for i = 1:length(lhdirlist)
            sess_tok = regexp(lhdirlist(i).name, '_ses-([A-Za-z0-9]+)_', 'tokens');
            sess_ids{end+1} = sess_tok{1}{1};
        end
        numofsess(s) = length(unique(sess_ids));
    else
        numofsess(s)=length(lhdirlist);
    end
    
end

mainoutdir=[output_dir '/Params_' SUBin];
copyfile([mainoutdir '/Params_training'],[mainoutdir '/Params_training_' num2str(numofnet)])
load([codedir '/MSHBM/MSHBM_prior_15.mat']);
lh_profile=[mainoutdir '/Params_training/generate_profiles_and_ini_params/profiles/avg_profile/lh_fsaverage6_roifsaverage3_avg_profile.nii.gz'];
rh_profile=[mainoutdir '/Params_training/generate_profiles_and_ini_params/profiles/avg_profile/rh_fsaverage6_roifsaverage3_avg_profile.nii.gz'];
clustered = CBIG_IndCBM_generate_MSHBM_params(lh_profile, rh_profile, lh_labels_fs6, rh_labels_fs6);

lh_labels=lh_labels_fs6;
rh_labels=rh_labels_fs6;
GroupFileDir1=[mainoutdir '/Params_training_' num2str(numofnet) '/estimate_group_priors/group/group.mat'];
GroupFileDir2=[mainoutdir '/Params_training_' num2str(numofnet) '/generate_profiles_and_ini_params/group/group.mat'];
mkdir([mainoutdir '/Params_training_' num2str(numofnet) '/estimate_group_priors/group/']);
mkdir([mainoutdir '/Params_training_' num2str(numofnet) '/generate_profiles_and_ini_params/group/']);
save(GroupFileDir1,'lh_labels','rh_labels','clustered');
save(GroupFileDir2,'lh_labels','rh_labels','clustered');

% compute model parameters- Params_Final.mat
project_dir=[mainoutdir '/Params_training_' num2str(numofnet) '/estimate_group_priors/'];
maxsess=max(numofsess);
numofsub=length(SUB);
% Stopping rule: CBIG_MSHBM_estimate_group_priors stops the outer (inter-
% subject) EM loop when |delta_cost/cost| <= conv_th OR iter_inter >= max_iter
% (see step2_estimate_priors/CBIG_MSHBM_estimate_group_priors.m ~L286-288).
% conv_th=1e-5 is the REAL stopping criterion; max_iter=100 is only a safety
% cap for the pathological case where the cost never converges. In practice
% these runs converge in ~2-4 outer iterations, so the cap does not bind
% (verified: Params_iteration*.mat counts of 2-3 and "inter interation" log
% maxima of 2-3 across the sess_grouped and s10 runs).
% NOTE: the earlier 'max_iter','5' here (copied from CBIG's 2-subject toy
% example) did NOT truncate training or cause the amoeba-shaped parcels --
% every completed run converged in <5 outer iterations, so the cap never
% bound. Keep max_iter=100 as a generous safety margin, not as a quality fix.
Params = CBIG_MSHBM_estimate_group_priors(project_dir,'fsaverage6',num2str(numofsub),num2str(maxsess),num2str(numofnet),'max_iter','100','conv_th','1e-5');
CBIG_IndCBM_extract_MSHBM_result_SUB(project_dir,SUB);
label2cifti(fullfile([project_dir '/ind_parcellation/']),codedir);

end