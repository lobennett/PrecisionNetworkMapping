function MSHBM_Params_Training(sub_list,numofnet,output_dir,codedir)

% MSHBM_Params_Training - Train MSHBM parameters and extract network assignments
% Written by Jingnan Du and Noam Saadon-Grosman
% Contact Jingnan Du at jingnandu@fas.harvard.edu if you have any questions


addpath(genpath(fullfile([codedir '/MSHBM'])))
% addpath(genpath(fullfile([codedir '/ncf_tools']))) 

numofnet=str2double(numofnet);
sub_list_table=readtable(sub_list,'Delimiter',',','ReadVariableNames',false);
SUB=(table2cell(sub_list_table(:,1)))';
partition=(table2cell(sub_list_table(:,2)))';
% construct output folder name from full subject IDs (BIDS-compliant)
SUBin = strjoin(SUB, '_');

for s=1:length(SUB)

    datadir=partition{s};
    cd(fullfile([datadir SUB{s}]))
    lhdirlist = dir('lh*nat_resid_bpss_fsaverage6_sm*.nii.gz');
    rhdirlist = dir('rh*nat_resid_bpss_fsaverage6_sm*.nii.gz');
    numofsess(s)=length(lhdirlist);
    
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
save(GroupFileDir1,'lh_labels','rh_labels','clustered');
save(GroupFileDir2,'lh_labels','rh_labels','clustered');

% compute model parameters- Params_Final.mat
project_dir=[mainoutdir '/Params_training_' num2str(numofnet) '/estimate_group_priors/'];
maxsess=max(numofsess);
numofsub=length(SUB);
Params = CBIG_MSHBM_estimate_group_priors(project_dir,'fsaverage6',num2str(numofsub),num2str(maxsess),num2str(numofnet),'max_iter','5');
CBIG_IndCBM_extract_MSHBM_result_SUB(project_dir,SUB);
label2cifti(fullfile([project_dir '/ind_parcellation/']),codedir);

end