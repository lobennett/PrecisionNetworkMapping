function label2cifti(OUTFOLDER,codedir)

% Written by Jingnan Du
% Adapted for Sherlock HPC by Logan Bennett
% Contact Jingnan Du at jingnandu@fas.harvard.edu if you have any questions

colorfile= [codedir '/MSHBM/ColorMap_15.txt'];
matdir= dir([OUTFOLDER '*mat']);
FILENAME='MSHBM';

% Use wb_command from PATH (loaded via module load workbench)
wb_cmd = 'wb_command';

% FreeSurfer fsaverage6 surfaces (from FREESURFER_HOME)
% Convert native FreeSurfer inflated surfaces to GIFTI for wb_command
fs_home = getenv('FREESURFER_HOME');
lh_surf_fs = [fs_home '/subjects/fsaverage6/surf/lh.inflated'];
rh_surf_fs = [fs_home '/subjects/fsaverage6/surf/rh.inflated'];
lh_surf_gii = [tempdir 'lh.inflated.surf.gii'];
rh_surf_gii = [tempdir 'rh.inflated.surf.gii'];
if ~exist(lh_surf_gii, 'file')
    system(['mris_convert ' lh_surf_fs ' ' lh_surf_gii]);
end
if ~exist(rh_surf_gii, 'file')
    system(['mris_convert ' rh_surf_fs ' ' rh_surf_gii]);
end

for i = 1:length(matdir)
    label_mat = fullfile(matdir(i).folder,matdir(i).name);
    load(label_mat)

    % Find the position of "sub" in filename only (not full path)
    fname = matdir(i).name;
    sub_idx = strfind(fname, 'sub');

    % Find the first underscore after "sub"
    underscore_idx = find(fname(sub_idx(1):end) == '_', 1) + sub_idx(1) - 1;

    SUB = fname(underscore_idx+1:end-4);
    OUTDIR = fullfile([OUTFOLDER,SUB]);
    mkdir(OUTDIR);

    g = ciftiopen([codedir '/MSHBM/fsaverage6_cifti_template.dscalar.nii'],wb_cmd,1)
    g.cdata=[lh_labels; rh_labels];
    dlabel = [' ' OUTDIR '/' SUB '_' FILENAME '.dlabel.nii'];

    ciftisavereset(g,fullfile([OUTDIR '/' SUB '_' FILENAME '.dscalar.nii']),wb_cmd)
    system([wb_cmd ' -cifti-label-import ' fullfile([OUTDIR '/' SUB '_' FILENAME '.dscalar.nii ']) colorfile fullfile([' ' OUTDIR '/' SUB '_' FILENAME '.dlabel.nii'])])
    system([wb_cmd ' -cifti-separate ' dlabel ' COLUMN -label CORTEX_LEFT ' dlabel(1:end-11) '_lh.label.gii -label CORTEX_RIGHT ' dlabel(1:end-11) '_rh.label.gii'])
    system([wb_cmd ' -label-to-border ' lh_surf_gii ' ' dlabel(1:end-11) '_lh.label.gii ' dlabel(1:end-11) '_lh.border -placement 0.5'])
    system([wb_cmd ' -label-to-border ' rh_surf_gii ' ' dlabel(1:end-11) '_rh.label.gii ' dlabel(1:end-11) '_rh.border -placement 0.5'])

end

end
