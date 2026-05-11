function MSHBM_wrapper(sub_list,output_dir,codedir)

% MSHBM_wrapper - Generate Functional Connectivity Profiles
% Written by Jingnan Du and Noam Saadon-Grosman
% Contact Jingnan Du at jingnandu@fas.harvard.edu if you have any questions


addpath(genpath(fullfile([codedir '/MSHBM'])))

sub_list_table=readtable(sub_list,'Delimiter',',','ReadVariableNames',false);
SUB=(table2cell(sub_list_table(:,1)))';
partition=(table2cell(sub_list_table(:,2)))';

% create output folder name from full subject IDs (BIDS-compliant)
% For small cohorts, use joined IDs (preserves the original behavior).
% For large cohorts, the joined name would exceed the 255-byte filesystem
% limit, so fall back to a count-based name.
SUBin = strjoin(SUB, '_');
if length(SUBin) > 200
    SUBin = ['cohort_N' num2str(length(SUB))];
end
mainoutdir=[output_dir '/Params_' SUBin];
mkdir(mainoutdir);
copyfile([codedir '/MSHBM/MSHBM_folder_structure_template'],[mainoutdir '/Params_training']);
outdir=[mainoutdir '/Params_training/generate_profiles_and_ini_params/data_list/fMRI_list/'];
% create text files that contain the full path of fixation data:
numofsess = zeros(length(SUB),1);
for s=1:length(SUB)
    
    datadir=partition{s};
    cd(fullfile([datadir SUB{s}]))
    lhdirlist = dir('lh*nat_resid_bpss_fsaverage6_sm*.nii.gz');
    rhdirlist = dir('rh*nat_resid_bpss_fsaverage6_sm*.nii.gz');
    
    numofsess(s)=length(lhdirlist);
    for i =1:length(lhdirlist)
        dirname = [lhdirlist(i).folder '/' lhdirlist(i).name];
        filetext = fopen([outdir 'lh_sub' num2str(s) '_sess' num2str(i) '.txt'],'w');
        fprintf(filetext,dirname);
        fclose(filetext);
    end
    for i =1:length(rhdirlist)
        dirname = [rhdirlist(i).folder '/' rhdirlist(i).name];
        filetext = fopen([outdir 'rh_sub' num2str(s) '_sess' num2str(i) '.txt'],'w');
        fprintf(filetext,dirname);
        fclose(filetext);
    end
    
end
%% generate profiles
project_dir=[mainoutdir '/Params_training/generate_profiles_and_ini_params/'];

for i=1:length(SUB)
    sub=i;
    for sess = 1:numofsess(i)
        CBIG_MSHBM_generate_profiles('fsaverage3','fsaverage6',project_dir,num2str(sub),num2str(sess),'0');
    end
end
%%
% creat text files with profiles directories
datadir=[mainoutdir '/Params_training/generate_profiles_and_ini_params/profiles/'];
profile_outdir=[mainoutdir '/Params_training/generate_individual_parcellations/profile_list/test_set/'];
for j=1:length(SUB)
    j
    cd([datadir '/sub' num2str(j) '/'])
    lh = dir('*/lh*roifsaverage3.surf2surf_profile.nii.gz');
    rh = dir('*/rh*roifsaverage3.surf2surf_profile.nii.gz');
    eval(['sub' num2str(j) '_lhdirlist = lh']);
    eval(['sub' num2str(j) '_rhdirlist = rh']);
end

[maxsess,indmaxsess] = max(numofsess);

for j=1:length(SUB)
    for k = 1:numofsess(j)
        eval(['pathname_lh1 = sub' num2str(j) '_lhdirlist(k).folder']);
        eval(['pathname_lh2 = sub' num2str(j) '_lhdirlist(k).name']);
        indstr=eval(['sub' num2str(j) '_lhdirlist(k).name' '(13:14)']);
        if indstr(2)=='_'
            ind=str2double(indstr(1));
        else
            ind=str2double(indstr(1:2));
        end
        str_lh{ind} = [pathname_lh1 '/' pathname_lh2];
        eval(['pathname_rh1 = sub' num2str(j) '_rhdirlist(k).folder']);
        eval(['pathname_rh2 = sub' num2str(j) '_rhdirlist(k).name']);
        str_rh{ind} = [pathname_rh1 '/' pathname_rh2];
    end
    if numofsess(j)<maxsess
        for k = numofsess(j)+1:maxsess
            str_lh{k} = 'NONE';
            str_rh{k} = 'NONE';
        end
    end
    eval(['str_lh_sub' num2str(j) '= str_lh']);
    eval(['str_rh_sub' num2str(j) '= str_rh']);
    
end

for i=1:length(str_lh_sub1) 
    for s=1:length(SUB)
        eval(['temp_lh_' num2str(s) '= str_lh_sub' num2str(s) '{i}']);
        eval(['temp_rh_' num2str(s) '= str_rh_sub' num2str(s) '{i}']);
    end
    eval(['tpname=temp_lh_' num2str(indmaxsess)]);
    sessName=tpname(length(tpname)-51:length(tpname)-49);
    if sessName(1)=='s'
        filetext_lh = fopen([profile_outdir 'lh_sess' sessName(2) '.txt'],'w');
        filetext_rh = fopen([profile_outdir 'rh_sess' sessName(2) '.txt'],'w');
    else
        filetext_lh = fopen([profile_outdir 'lh_sess' sessName(1:2) '.txt'],'w');
        filetext_rh = fopen([profile_outdir 'rh_sess' sessName(1:2) '.txt'],'w');
    end
    printstr_lh = [];
    printstr_rh = [];
    for s=1:length(SUB)
        a1_lh = ['temp_lh_' num2str(s)];
        a1_rh = ['temp_rh_' num2str(s)];
        a2 = '\n';
        printstr_lh=[printstr_lh ' ' char(39) a2 char(39) ' ' a1_lh];
        printstr_rh=[printstr_rh ' ' char(39) a2 char(39) ' ' a1_rh];
    end
    
    printstr_lh=printstr_lh(7:end);
    printstr_rh=printstr_rh(7:end);
    
    fprintf(filetext_lh,eval(['[' printstr_lh ']']));
    fclose(filetext_lh);
    
    fprintf(filetext_rh,eval(['[' printstr_rh ']']));
    fclose(filetext_rh);
    
end
profile_training=[mainoutdir '/Params_training/estimate_group_priors/profile_list/training_set/'];
copyfile(profile_outdir,profile_training);
%%
project_dir=[mainoutdir '/Params_training/generate_profiles_and_ini_params/'];
num_sub = length(SUB);
num_sess = maxsess;
CBIG_MSHBM_avg_profiles('fsaverage3','fsaverage6',project_dir,num2str(num_sub),num2str(num_sess));
end
