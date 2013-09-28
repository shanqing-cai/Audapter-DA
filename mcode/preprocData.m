function preprocData(expDir, cacheDir, varargin)
%% Configs
hostName = getHostName;

MAIN_UTTER_RHY = 'The steady bat gave birth to pups';

% dacacheDir='E:/speechres/rhythm-fmri/dacache';
% rawDataBase='G:/DATA/RHYTHM-FMRI/';

mvaWinWidth=21;     % 21 * 1.333 = 28 (ms)
fineParseWin=100e-3;	% sec

ylim=[0,5000];
rmsOneSide=0.01;  % Unit: sec
rmsLBRatio=0.75;
shiraOneSide=0.025; % Unit: sec

MAX_N_WORDS = 8;



% DEFAULT_SORT_MODE ={'behav', {'bRhythm', 'stimUtter'};      % Legacy
%                     'fMRI',  {'bRhythm', 'stimUtter'};       % Legacy
%                     'sust-fmt', {'noiseMasked', 'stimUtter'}};
                
%% Set path 
tpath = which('list_cbk');
if isempty(tpath)
    mfp = fileparts(mfilename('fullpath'));
    addpath(fullfile(mfp, 'preproc'));
end

%%
if ~isdir(expDir)
    error_log(sprintf('Cannot find directory %s', expDir));
end

if ~isfile(fullfile(expDir,'expt.mat'))
    error_log(sprintf('Cannot find expt.mat in directory %s', expDir));
end

%% Determine the type of experiment
exptType = guessExptType(expDir);
if isempty(exptType)
    error_log('Failed to determine the type of the experiment');
else
    info_log(sprintf('Determined type of experiment as: %s', exptType));
end

daSettings = data_analysis_settings(exptType);


%%
if ~exist('cacheDir', 'var')
    cacheDir = daSettings.DA_CACHE_DIR;
    info_log(sprintf('Cache directory specified in external configuration: %s', cacheDir));
end

if ~isdir(cacheDir)
    error_log(sprintf('Cannot find cache base directory: %s', cacheDir));
end

%%
load(fullfile(expDir,'expt.mat'));  % gives expt

subjID = expt.subject.name;
info_log(sprintf('Subject ID: \t%s', subjID));
info_log(sprintf('Subject gender: \t%s', expt.subject.sex));

pdata = struct;

pdata.subject = expt.subject;
pdata.mvaWinWidth = mvaWinWidth;

dacacheFN = fullfile(cacheDir, [pdata.subject.name, '.mat']);
stateFN = fullfile(cacheDir, [pdata.subject.name, '_state.mat']);



%% Calculate the total number of speech trials
% --- Determine the phases to process --- %
allPhaseNames = {'pract1', 'pract2', 'pre', 'run1', 'run2', 'run3', 'run4', 'run5', 'run6', ...
                 'inter1', 'inter2', 'inter3', 'inter4', 'inter5', ...
                 'start', 'ramp', 'stay', 'end', 'stay1', 'stay2'};
bPhaseToProc = [0, 0, 0, 1, 1, 1, 1, 1, 1, ...
                1, 1, 1, 1, 1, ...
                1, 1, 1, 1, 1, 1];
assert(length(allPhaseNames) == length(bPhaseToProc));

procPhases = {};
ord = [];
dd = dir(fullfile(expDir, '*'));
for i1 = 1 : numel(dd)
    fdn = fullfile(expDir, dd(i1).name);
    if ~isdir(fdn) || isequal(dd(i1).name, '.') || isequal(dd(i1).name, '..')
        continue;
    end
    
    if isempty(fsic(allPhaseNames, dd(i1).name))
        info_log(sprintf('Found a directory of which the name does not seem to be a know phase name: %s', dd(i1).name), '-warn');
    else
        if bPhaseToProc(fsic(allPhaseNames, dd(i1).name))
            procPhases{end + 1} = dd(i1).name;
            ord(end + 1) = fsic(allPhaseNames, dd(i1).name);
        end
    end
end

[ord, srtIdx] = sort(ord);
procPhases = procPhases(srtIdx);

info_log(sprintf('Found %d phases to process', numel(procPhases)));

%%
% %--- In the case of an MRI experiment, there may be more runs ---%
% %--- If so, include them! ---%
% nRunsAct = 0;   % Actual number of runs
% while isdir(fullfile(expDir, sprintf('run%d', nRunsAct + 1)))
%     nRunsAct = nRunsAct + 1;
%     
%     runStr = sprintf('run%d', nRunsAct);
%     if isempty(fsic(procPhases, runStr));
%         procPhases{end + 1} = runStr;
%     end
% end

if isequal(exptType, 'rand-twarp-fmt')
    MAIN_UTTER = MAIN_UTTER_RHY;
else
    MAIN_UTTER = '';
end

[rawDataBase, ~] = fileparts(expDir);
[mainData, exptType] = init_data(exptType, MAIN_UTTER, procPhases, expt, rawDataBase, subjID);

pdata.mainData = mainData;

%% Build a list of all trials
if isfile(stateFN)
    info_log(sprintf('Found state.mat at %s.\n', stateFN));
    if isempty(fsic(varargin, 'phase')) && isempty(fsic(varargin, 'pdata_fixAutoRMS'))
        answer = input('Resume? (0/1): ');
    else
        answer = 1;
    end
    if answer==1
        load(stateFN);  % gives state
        load(dacacheFN);    % gives pdata
        
        trialList = state.trialList;
%         trialListPert = state.trialListPert;
        
        bNew = 0;
    else
        answer = input('Are you sure you want to start the screening process over? (0/1): ');
        if answer == 1
            bNew=1;
        else
            return
        end
    end
else
    bNew=1;
end

if bNew
    if isfile(dacacheFN)
        delete(dacacheFN);
        fprintf('%s deleted.\n',dacacheFN);
    end
    
    info_log('Creating new pdata and state files...');
%     fprintf('Getting information about all trials...\n');

    trialList.fn={};
    trialList.phase={};
    trialList.block=[];
    trialList.trialN=[];   
    trialList.word={};
    trialList.allOrderN=[];
    
%     fprintf('Randomizing the order of all trials...\n');
    
    idxN = find(mainData.bRhythm ~= 1);
    idxR = find(mainData.bRhythm == 1);
    
    trialList.fn = mainData.rawDataFNs;
    trialList.phase = mainData.phases;
    trialList.block = mainData.blockNums;
    trialList.trialN = mainData.trialNums;
    trialList.word = mainData.words;
    trialList.bRhythm = mainData.bRhythm;
    trialList.pertType = mainData.pertType;    
    trialList.noiseMasked = mainData.noiseMasked;
   
    trialList.allOrderN = 1 : numel(mainData.trialNums);
    
    %--- Determine sorting scheme ---%
%     isrt = fsic(daSettings.DEFAULT_SORT_MODE(:, 1), exptType);
%     if isempty(isrt)
%         error_log({'Cannot determine the default trial sorting scheme for exptType; %s', exptType});
%     end
    defSrtMode = daSettings.DEFAULT_SORT_MODE;
    
    trialList = sort_trial_list(trialList, defSrtMode);
    info_log('Done initial sorting of trials based on default sorting mode');
    
    state.exptType = exptType;
    
    state.trialList = trialList;
%     state.trialListPert = trialListPert;
    
    state.rawDataDir = rawDataBase;
    state.dacacheDir = cacheDir;
    state.expDir = expDir;
    
    state.persist_rmsThresh = NaN;
    state.bFirstTime = 1;
    
    state.stats = zeros(1, numel(state.trialList.fn));
%     state.statsPert = zeros(1, numel(state.trialListPert.fn));   
    
    save(stateFN, 'state');
    save(dacacheFN, 'pdata');
    
    info_log(sprintf('Saved state info to %s', stateFN));
    info_log(sprintf('Saved pdata to %s', dacacheFN));
else
    load(stateFN);
    load(dacacheFN);
    
    state.bFirstTime = 1;
end

dataFld = 'mainData';
if ~isfield(pdata.(dataFld), 'fluency_comments')
    pdata.(dataFld).fluency_comments = cell(size(pdata.(dataFld).rawDataFNs));
    save(dacacheFN, 'pdata');
end

%%
uihdls = struct;
uihdls.exptType = exptType;
uihdls.dacacheFN = dacacheFN;

bIsRHY = ~isfield(uihdls, 'exptType') || isequal(uihdls.exptType, 'behav') || isequal(uihdls.exptType, 'fMRI') || ...
         isequal(uihdls.exptType, 'rand-twarp-fmt') || isequal(uihdls.exptType, 'rand-RHY-fmri');

uihdls.hfig_aux = gen_comp_fig;
set(uihdls.hfig_aux, 'Visible', 'off');

uihdls.hfig = figure('Position', [20, 150, 1560, 600]);
hlist_title = uicontrol('Style', 'text', ...
                  'Unit', 'Normalized', ...
                  'Position', [0.02, 0.93, 0.18, 0.05], ...
                  'String', 'Trial list: (*: preprocessing done)', ...
                  'HorizontalAlignment', 'left');
uihdls.hlist_title = hlist_title;


hlist = uicontrol('Style', 'listbox', ...
                  'Unit', 'Normalized', ...
                  'Position', [0.02, 0.15, 0.15, 0.8], ...
                  'BackgroundColor', [1, 1, 1]);
uihdls.hlist = hlist;

uihdls.hmenu_nLPC = uimenu('Parent', uihdls.hfig, 'Label', 'nLPC');
set(uihdls.hfig, 'MenuBar', 'none');
uihdls.hmenu_nLPC_show_overall_best = uimenu(uihdls.hmenu_nLPC, ...
                                        'Label', 'Show overall best');
uihdls.hmenu_nLPC_set_overall_best = uimenu(uihdls.hmenu_nLPC, ...
                                        'Label', 'Set all trials to overall best');
uihdls.hmenu_nLPC_set_list_1st = uimenu(uihdls.hmenu_nLPC, ...
                                        'Label', 'Set all trials to 1st in list', 'Separator', 'on');
uihdls.hmenu_nLPC_restore_user = uimenu(uihdls.hmenu_nLPC, ...
                                        'Label', 'Restore user selections', 'Separator', 'on');                                   
                                    
uihdls.hmenu_comments = uimenu('Parent', uihdls.hfig, 'Label', 'Comments');
uihdls.hmenu_comments_recover = uimenu(uihdls.hmenu_comments, ...
                                       'Label', 'Recover from file...');
                                   
uihdls.hmenu_rmsThresh = uimenu('Parent', uihdls.hfig, 'Label', 'rmsThresh');
uihdls.hmenu_rmsThresh_scan = uimenu('Parent', uihdls.hmenu_rmsThresh, ...
                                     'Label', 'Scan for trials with gaps');

uihdls.hmenu_asr = uimenu('Parent', uihdls.hfig, 'Label', 'ASR');
uihdls.hmenu_genASRTimeLabels = uimenu('Parent', uihdls.hmenu_asr, ...
                                       'Label', 'Generate time labels from ASR results');
uihdls.hmenu_asrOnFB = uimenu('Parent', uihdls.hmenu_asr, ...
                                       'Label', 'Run ASR on auditory feedback');
                                   
uihdls.hmenu_formants = uimenu('Parent', uihdls.hfig, 'Label', 'Formants');
uihdls.hmenu_gen_vwl_fmts_trial = uimenu('Parent', uihdls.hmenu_formants, ...
                                         'Label', 'Generate vowel formant for current trial');
uihdls.hmenu_gen_vwl_fmts_all = uimenu('Parent', uihdls.hmenu_formants, ...
                                       'Label', 'Generate vowel formant for all valid trials');
uihdls.hmenu_calc_avg_vwl_spect = uimenu('Parent', uihdls.hmenu_formants, ...
                                       'Label', 'Calculate average vowel spectrogram from all valid trials');

%--- Menus for trial sorting order ---%
uihdls.hmenu_sortTrials = uimenu('Parent', uihdls.hfig, 'Label', 'Sort');
uihdls.hmenu_sortTrials_lvs = nan(daSettings.SORT_TRIAL_LEVELS, 1);
uihdls.hmenu_sortTrials_opts = nan(daSettings.SORT_TRIAL_LEVELS, length(daSettings.ALL_SORT_MODES_DESC));

% isrt = fsic(DEFAULT_SORT_MODE(:, 1), uihdls.exptType);
defSrtMode = daSettings.DEFAULT_SORT_MODE;

for i1 = 1 : daSettings.SORT_TRIAL_LEVELS
    uihdls.hmenu_sortTrials_lvs(i1) = uimenu('Parent', uihdls.hmenu_sortTrials , 'Label', sprintf('Level %d', i1));
    
    
    for i2 = 1 : length(daSettings.ALL_SORT_MODES_DESC)
        uihdls.hmenu_sortTrials_opts(i1, i2) = uimenu('Parent', uihdls.hmenu_sortTrials_lvs(i1), ...
                                                      'Label', daSettings.ALL_SORT_MODES_DESC{i2});

        selIdx = fsic(daSettings.ALL_SORT_MODES, defSrtMode(i1));
    	if i2 == selIdx
            set(uihdls.hmenu_sortTrials_opts(i1, i2), 'checked', 'on');
        end
    end
end

%--- ~Menus for trial sorting order ---%

uihdls.hreveal = uicontrol('Style', 'pushbutton', ...
                    'Unit', 'Normalized', ...
                    'Position', [0.02, 0.04, 0.18, 0.04], ...
                    'String', 'Reveal trial details');

hShowComments = uicontrol('Style', 'pushbutton', ...
                          'Unit', 'Normalized', ...
                          'Position', [0.02, 0.09, 0.18, 0.04], ...
                          'String', 'Show comments');
uihdls.hShowComments = hShowComments;

% htitle = uicontrol('Style', 'text', ...
%                    'Unit', 'Normalized', ...
%                    'Position', [0.24, 0.93, 0.3, 0.04], ...
%                    'String', 'Title', ...
%                    'FontSize', 12);
% uihdls.htitle = htitle;

haxes1 = axes('Unit', 'Normalized', 'Position', [0.21, 0.26, 0.63, 0.68]);
uihdls.haxes1 = haxes1;

haxes2 = axes('Unit', 'Normalized', 'Position', [0.21, 0.13, 0.63, 0.15]);
uihdls.haxes2 = haxes2;

% Zoom buttons
hzo = uicontrol('Style', 'pushbutton', ...
                'Unit', 'Normalized', ...
                'Position', [0.24, 0.025, 0.10, 0.045], ...
                'String', 'Zoom out');
uihdls.hzo = hzo;

hzi = uicontrol('Style', 'pushbutton', ...
                'Unit', 'Normalized', ...
                'Position', [0.34, 0.025, 0.10, 0.045], ...
                'String', 'Zoom in');
uihdls.hzi = hzi;

hpleft = uicontrol('Style', 'pushbutton', ...
                   'Unit', 'Normalized', ...
                   'Position', [0.46, 0.025, 0.10, 0.045], ...
                   'String', 'Pan left');
uihdls.hpleft = hpleft;

hpright = uicontrol('Style', 'pushbutton', ...
                   'Unit', 'Normalized', ...
                   'Position', [0.56, 0.025, 0.10, 0.045], ...
                   'String', 'Pan right');
uihdls.hpright = hpright;

hzd = uicontrol('Style', 'pushbutton', ...
                'Unit', 'Normalized', ...
                'Position', [0.68, 0.025, 0.10, 0.045], ...
                'String', 'Default zoom');
uihdls.hzd = hzd;

uihdls.bt_playSigIn = uicontrol('Style', 'pushbutton', ...
                         'Unit', 'Normalized', ...
                         'Position', [0.87, 0.88, 0.07, 0.04], ...
                         'String', 'Play sigIn');
uihdls.bt_playSigOut = uicontrol('Style', 'pushbutton', ...
                         'Unit', 'Normalized', ...
                         'Position', [0.87, 0.83, 0.07, 0.04], ...
                         'String', 'Play sigOut');

rb_alwaysPlaySigIn = uicontrol('Style', 'radiobutton', ...
                               'Unit', 'Normalized', ...
                               'Position', [0.945, 0.88, 0.055, 0.04], ...
                               'String', 'Always play');
uihdls.rb_alwaysPlaySigIn = rb_alwaysPlaySigIn;

uihdls.bt_compareSigInOut = uicontrol('Style', 'pushbutton', ...
                                      'Unit', 'Normalized', ...
                                      'Position', [0.94, 0.83, 0.055, 0.04], ...
                                      'String', 'Compare in/out');

uihdls.rb_doMarks = uicontrol('Style', 'radiobutton', ...
                       'Unit', 'Normalized', ...
                       'Position', [0.945, 0.93, 0.055, 0.04], ...
                       'String', 'Do marks');
if ~bIsRHY
    set(uihdls.rb_doMarks, 'enable', 'off');
end

lblLeft = 0.845;
lblWidth = 0.04;
editLeft = 0.89;
editWidth = 0.04;
lbl_rmsThresh = uicontrol('Style', 'text', ...
                         'Unit', 'Normalized', ...
                         'Position', [lblLeft, 0.78, lblWidth, 0.04], ...
                         'String', 'rmsThresh: ');
uihdls.lbl_rmsThresh = lbl_rmsThresh;
edit_rmsThresh = uicontrol('Style', 'edit', ...
                         'Unit', 'Normalized', ...
                         'Position', [editLeft, 0.78, editWidth, 0.04], ...
                         'String', 'rmsThresh', 'HorizontalAlignment', 'left');
uihdls.edit_rmsThresh = edit_rmsThresh;

uihdls.bt_auto_rmsThresh = uicontrol('Style', 'pushbutton', ...
                                     'Unit', 'Normalized', ...
                                     'Position', [editLeft + editWidth + 0.004, 0.78, editWidth * 1.65, 0.04], ...
                                     'String', 'Auto rmsThresh', 'FontSize', 8);
set(uihdls.bt_auto_rmsThresh, 'enable', 'off');

bt_auto_rmsThresh_all = uicontrol('Style', 'pushbutton', ...
                             'Unit', 'Normalized', ...
                             'Position', [editLeft + editWidth + 0.004, 0.73, editWidth * 1.65, 0.04], ...
                             'String', 'Auto rmsThresh all', 'FontSize', 8);
uihdls.bt_auto_rmsThresh_all = bt_auto_rmsThresh_all;
set(uihdls.bt_auto_rmsThresh_all, 'enable', 'off');

                     
lbl_nLPC = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.72, lblWidth, 0.04], ...
                     'String', 'nLPC: ');
uihdls.lbl_nLPC = lbl_nLPC;
edit_nLPC = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.72, editWidth, 0.04], ...
                      'String', 'nLPC', 'HorizontalAlignment', 'left');
uihdls.edit_nLPC = edit_nLPC;


uihdls.bt_auto_nLPC = uicontrol('Style', 'pushbutton', ...
                         'Unit', 'Normalized', ...
                         'Position', [editLeft + editWidth + 0.004, 0.65, editWidth * 1.5, 0.04], ...
                         'String', 'Auto nLPC', ...
                         'FontSize', 8);
set(uihdls.bt_auto_nLPC, 'enable', 'off');

lbl_srt_nLPCs = uicontrol('Style', 'text', ...
                         'Unit', 'Normalized', ...
                         'Position', [editLeft + editWidth + 0.004, 0.59, editWidth * 1.5, 0.04], ...
                         'String', 'Sorted nLPCs: ', 'HorizontalAlignment', 'left', ...
                         'FontSize', 8);
uihdls.lbl_srt_nLPCs = lbl_srt_nLPCs; 

lst_srt_nLPCs = uicontrol('Style', 'listbox', ...
                         'Unit', 'Normalized', ...
                         'Position', [editLeft + editWidth + 0.004, 0.44, editWidth * 1.5, 0.16], ...
                         'String', {}, 'Enable', 'off', ...
                         'FontSize', 8);
uihdls.lst_srt_nLPCs = lst_srt_nLPCs;

uihdls.bt_auto_nLPC_all = uicontrol('Style', 'pushbutton', ...
                         'Unit', 'Normalized', ...
                         'Position', [editLeft + editWidth + 0.004, 0.38, editWidth * 1.5, 0.04], ...
                         'String', 'Auto nLPC all', ...
                         'FontSize', 8);
set(uihdls.bt_auto_nLPC_all, 'enable', 'off');

% bt_best_nLPC = uicontrol('Style', 'pushbutton', ...
%                          'Unit', 'Normalized', ...
%                          'Position', [editLeft + editWidth + 0.004, 0.32, editWidth * 1.5, 0.04], ...
%                          'String', 'Overall best nLPC', ...
%                          'FontSize', 8);
% uihdls.bt_best_nLPC = bt_best_nLPC;

lbl_fn1 = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.67, lblWidth, 0.04], ...
                     'String', 'fn1: ');
uihdls.lbl_fn1 = lbl_fn1;
edit_fn1 = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.67, editWidth, 0.04], ...
                      'String', 'fn1', 'HorizontalAlignment', 'left');
uihdls.edit_fn1 = edit_fn1;
                  
lbl_fn2 = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.62, lblWidth, 0.04], ...
                     'String', 'fn2: ');
uihdls.lbl_fn2 = lbl_fn2;
edit_fn2 = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.62, editWidth, 0.04], ...
                      'String', 'fn2', 'HorizontalAlignment', 'left');
uihdls.edit_fn2 = edit_fn2;
                  
lbl_aFact = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.56, lblWidth, 0.04], ...
                     'String', 'aFact: ');
uihdls.lbl_aFact = lbl_aFact;
edit_aFact = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.56, editWidth, 0.04], ...
                      'String', 'aFact', 'HorizontalAlignment', 'left');
uihdls.edit_aFact = edit_aFact;

lbl_bFact = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.51, lblWidth, 0.04], ...
                     'String', 'bFact: ');
uihdls.lbl_bFact = lbl_bFact;
edit_bFact = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.51, editWidth, 0.04], ...
                      'String', 'bFact', 'HorizontalAlignment', 'left');
uihdls.edit_bFact = edit_bFact;
                  
lbl_gFact = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.45, lblWidth, 0.04], ...
                     'String', 'gFact: ');
uihdls.lbl_gFact = lbl_gFact;
edit_gFact = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.45, editWidth, 0.04], ...
                      'String', 'gFact', 'HorizontalAlignment', 'left');
uihdls.edit_gFact = edit_gFact;

lbl_bCepsLift = uicontrol('Style', 'text', ...
                          'Unit', 'Normalized', ...
                          'Position', [lblLeft, 0.39, lblWidth, 0.04], ...
                          'String', 'bCepsLift: ');
uihdls.lbl_bCepsLift = lbl_bCepsLift;
edit_bCepsLift = uicontrol('Style', 'edit', ...
                           'Unit', 'Normalized', ...
                           'Position', [editLeft, 0.39, editWidth, 0.04], ...
                           'String', 'bCepsLift', 'HorizontalAlignment', 'left');
uihdls.edit_bCepsLift = edit_bCepsLift;

lbl_cepsWinWidth = uicontrol('Style', 'text', ...
                          'Unit', 'Normalized', ...
                          'Position', [lblLeft, 0.34, lblWidth, 0.04], ...
                          'String', 'cepsWinWidth: ');
uihdls.lbl_cepsWinWidth = lbl_cepsWinWidth;
edit_cepsWinWidth = uicontrol('Style', 'edit', ...
                           'Unit', 'Normalized', ...
                           'Position', [editLeft, 0.34, editWidth, 0.04], ...
                           'String', 'cepsWinWidth', 'HorizontalAlignment', 'left');
uihdls.edit_cepsWinWidth = edit_cepsWinWidth;
                  
bt_reproc = uicontrol('Style', 'pushbutton', ...
                      'Unit', 'Normalized', ...
                      'Position', [lblLeft, 0.30, 0.10, 0.025], ...
                      'String', 'Reprocess');
uihdls.bt_reproc = bt_reproc;

uihdls.bt_relabel = uicontrol('Style', 'pushbutton', ...
                      'Unit', 'Normalized', ...
                      'Position', [lblLeft, 0.96, 0.10, 0.035], ...
                      'String', 'ReLabel');
if isequal(uihdls.exptType, 'sust-fmt')
    set(uihdls.bt_relabel, 'enable', 'off');
end

uihdls.bt_relabel_focus = uicontrol('Style', 'pushbutton', ...
                             'Unit', 'Normalized', ...
                             'Position', [lblLeft, 0.925, 0.10, 0.035], ...
                             'String', 'Focus and ReLabel');
if isequal(uihdls.exptType, 'sust-fmt')
    set(uihdls.bt_relabel_focus, 'enable', 'off');
end
                  
lbl_rating = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft, 0.26, lblWidth, 0.03], ...
                     'String', 'Prod. rating: ');
uihdls.lbl_rating = lbl_rating;
pm_rating = uicontrol('Style', 'popupmenu', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.26, lblWidth, 0.03], ...
                      'String', {'0', '1', '2'}, ...
                      'HorizontalAlignment', 'left', ...
                      'BackgroundColor', 'w');
uihdls.pm_rating = pm_rating;

uihdls.lbl_ostOkay = uicontrol('Style', 'text', ...
                               'Unit', 'Normalized', ...
                               'Position', [lblLeft, 0.22, lblWidth, 0.03], ...
                               'String', 'OST: ');
uihdls.pm_ostOkay = uicontrol('Style', 'popupmenu', ...
                              'Unit', 'Normalized', ...
                              'Position', [editLeft, 0.22, lblWidth, 0.03], ...
                              'String', {'Good', 'Bad'}, ...
                              'HorizontalAlignment', 'left', ...
                              'BackgroundColor', 'w');
if ~bIsRHY
    set(uihdls.pm_ostOkay, 'enable', 'off');
end

lbl_asrOkay = uicontrol('Style', 'text', ...
                        'Unit', 'Normalized', ...
                        'Position', [lblLeft, 0.18, lblWidth, 0.03], ...
                        'String', 'ASR: ');
uihdls.lbl_asrOkay = lbl_asrOkay;
uihdls.pm_asrOkay = uicontrol('Style', 'popupmenu', ...
                      'Unit', 'Normalized', ...
                      'Position', [editLeft, 0.18, lblWidth, 0.03], ...
                      'String', {'Good', 'Bad'}, ...
                      'HorizontalAlignment', 'left', ...
                      'BackgroundColor', 'w');

uihdls.lbl_pertOkay = uicontrol('Style', 'text', ...
                                'Unit', 'Normalized', ...
                                'Position', [lblLeft, 0.14, lblWidth, 0.03], ...
                                'String', 'Pert: ');
uihdls.pm_pertOkay = uicontrol('Style', 'popupmenu', ...
                              'Unit', 'Normalized', ...
                              'Position', [editLeft, 0.14, lblWidth, 0.03], ...
                              'String', {'Good', 'Bad', 'N/A'}, ...
                              'HorizontalAlignment', 'left', ...
                              'BackgroundColor', 'w');

uihdls.lbl_comments = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft - lblWidth * 2.5, 0.08, lblWidth * 2.5, 0.03], ...
                     'HorizontalAlignment', 'left', ...
                     'String', 'Comments (e.g., unc {t1, d}):');
uihdls.edit_comments = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [lblLeft + 0.01, 0.08, 0.14, 0.03], ...
                      'String', 'Comments', ...
                      'HorizontalAlignment', 'left', ...
                      'BackgroundColor', 'w');

uihdls.lbl_fluency = uicontrol('Style', 'text', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft - lblWidth * 1.5, 0.015, lblWidth * 1.5, 0.05], ...
                     'String', 'Fluency comments:');
uihdls.edit_fluency = uicontrol('Style', 'edit', ...
                      'Unit', 'Normalized', ...
                      'Position', [lblLeft + 0.01, 0.05, 0.14, 0.03], ...
                      'String', '', ...
                      'HorizontalAlignment', 'left', ...
                      'BackgroundColor', 'w');

% --- Buttons for labeling fluency --- %
uihdls.fluencyBtnLabel = uicontrol('Style', 'Text', ...
                                'Unit', 'Normalized', ...
                                'Position', [lblLeft + 0.11, 0.32, 0.04, 0.025], ...
                                'String', 'Fluency', ...
                                'HorizontalAlignment', 'left');     

uihdls.utterWords = splitstring(MAIN_UTTER);
uihdls.btnFluencyWords = nan(1, MAX_N_WORDS);
for i1 = 1 : MAX_N_WORDS
    uihdls.btnFluencyWords(i1) = uicontrol('Style', 'pushbutton', ...
                                          'Unit', 'Normalized', ...
                                          'Position', [lblLeft + 0.11, 0.32 - 0.025 * i1, 0.04, 0.025], ...
                                          'String', sprintf('Word %d', i1), ...
                                          'ForegroundColor', 'g', ...
                                          'BackgroundColor', 'k', ...
                                          'HorizontalAlignment', 'left');
end
                  
bt_next = uicontrol('Style', 'pushbutton', ...
                     'Unit', 'Normalized', ...
                     'Position', [lblLeft + 0.05, 0.005, lblWidth * 2.5, 0.040], ...
                     'String', 'Next', 'FontSize', 11);
uihdls.bt_next = bt_next;

%% Set upcall back functions
set(uihdls.hlist, 'Callback', {@list_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.bt_playSigIn, 'Callback', {@playSig_cbk, dacacheFN, stateFN, uihdls, 'in'});
set(uihdls.bt_playSigOut, 'Callback', {@playSig_cbk, dacacheFN, stateFN, uihdls, 'out'});
set(uihdls.bt_compareSigInOut, 'Callback', {@playSig_cbk, dacacheFN, stateFN, uihdls, 'in/out'});

set(uihdls.bt_reproc, 'Callback', {@reproc_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.bt_relabel, 'Callback', {@relabel_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.bt_relabel_focus, 'Callback', {@relabel_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.pm_rating, 'Callback', {@rating_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.pm_ostOkay, 'Callback', {@ostOkay_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.pm_asrOkay, 'Callback', {@asrOkay_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.pm_pertOkay, 'Callback', {@pertOkay_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.edit_comments, 'Callback', {@comments_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.edit_fluency, 'Callback', {@fluency_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.bt_auto_rmsThresh, 'Callback', {@auto_rmsThresh_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.bt_auto_rmsThresh_all, 'Callback', {@auto_rmsThresh_all_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.bt_auto_nLPC, 'Callback', {@auto_nLPC_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.bt_auto_nLPC_all, 'Callback', {@auto_nLPC_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.hmenu_nLPC_show_overall_best, 'Callback', {@best_nLPC_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_nLPC_set_overall_best, 'Callback', {@best_nLPC_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_nLPC_set_list_1st, 'Callback', {@set_nLPC_list_1st, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_nLPC_restore_user, 'Callback', {@restore_user_nLPC, dacacheFN, stateFN, uihdls});

set(uihdls.hmenu_rmsThresh_scan, 'Callback', {@rmsThresh_scan_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_genASRTimeLabels, 'Callback', {@genASRTimeLabels_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_asrOnFB, 'Callback', {@runASROnFB_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.hmenu_gen_vwl_fmts_trial, 'Callback', {@gen_vwl_fmts_trial_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_gen_vwl_fmts_all, 'Callback', {@gen_vwl_fmts_all_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hmenu_calc_avg_vwl_spect, 'Callback', {@gen_vwl_fmts_all_cbk, dacacheFN, stateFN, uihdls});
% set(uihdls.bt_best_nLPC, 'Callback', {@best_nLPC_cbk, dacacheFN, stateFN, uihdls});

for i1 = 1 : daSettings.SORT_TRIAL_LEVELS
    for i2 = 1 : length(daSettings.ALL_SORT_MODES_DESC)
        set(uihdls.hmenu_sortTrials_opts(i1, i2), ...
            'Callback', {@sortTrial_menu_cbk, dacacheFN, stateFN, uihdls});
    end
end

set(uihdls.hmenu_comments_recover, 'Callback', {@recover_comments_from_file, dacacheFN, stateFN, uihdls});

set(uihdls.bt_next, 'Callback', {@next_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hreveal, 'Callback', {@reveal_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hShowComments, 'Callback', {@showComments_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.lst_srt_nLPCs, 'Callback', {@lst_srt_nLPCs_cbk, dacacheFN, stateFN, uihdls});

set(uihdls.bt_reproc, 'Enable', 'off');
set(uihdls.bt_auto_rmsThresh, 'Enable', 'off');

set(uihdls.hzo, 'Callback', {@zoom_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hzi, 'Callback', {@zoom_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hpleft, 'Callback', {@zoom_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hpright, 'Callback', {@zoom_cbk, dacacheFN, stateFN, uihdls});
set(uihdls.hzd, 'Callback', {@zoom_cbk, dacacheFN, stateFN, uihdls});

uihdls.utterWords = splitstring(MAIN_UTTER);
for i1 = 1 : MAX_N_WORDS
%     uWord = uihdls.utterWords{i1};
%     btnName = sprintf('bt_%s', uWord);
    
    set(uihdls.btnFluencyWords(i1), 'Callback', {@fluencyBtn_cbk, dacacheFN, stateFN, uihdls});
end

updateTrialList(state, uihdls);

%% Optional: jump to specified trial
if ~isempty(fsic(varargin, 'phase'))
    sp_phase = varargin{fsic(varargin, 'phase') + 1};
    sp_rep = varargin{fsic(varargin, 'rep') + 1};
    sp_tn = varargin{fsic(varargin, 'trial') + 1};
    
    bFound = 0;
    for idx = 1 : length(trialList.phase)
        if isequal(trialList.phase{idx}, sp_phase) && ...
           isequal(trialList.block(idx), sp_rep) && ...
           isequal(trialList.trialN(idx), sp_tn)
            bFound = 1;
            break;
        end
    end
    
    if ~bFound
        error('Cannot find specified trial in the trial list: phase=%s, rep=%d, trial=%d', sp_phase, sp_rep, sp_tn);
    end
    
    set(uihdls.hlist, 'Value', idx);
    list_cbk(uihdls.hlist, [], dacacheFN, stateFN, uihdls);
    drawnow;
end

return

function next_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
load(stateFN);
updateTrialList(state, uihdls, 'next', dacacheFN, stateFN); % gives state

return

function reveal_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
revButStr = get(uihdls.hreveal, 'String');
if isequal(revButStr, 'Reveal trial details')
    set(uihdls.hreveal, 'String', 'Hide trial details');
else
    set(uihdls.hreveal, 'String', 'Reveal trial details');
end

load(stateFN);  % gives state;
updateTrialList(state, uihdls)
return

function showComments_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
showCommentsStr = get(uihdls.hShowComments, 'String');
if isequal(showCommentsStr, 'Show comments')
    set(uihdls.hShowComments, 'String', 'Hide comments');
else
    set(uihdls.hShowComments, 'String', 'Show comments');
end

load(stateFN);  % gives state;
updateTrialList(state, uihdls)
return

%%
function restore_user_nLPC(hObject, eventdata, dacacheFN, stateFN, uihdls)
load(dacacheFN); % Gives pdata

flds = {'otherData', 'randData', 'sustData'};
bFoundMissing = 0;
a_nLPC_lst = [];
for h1 = 1 : numel(flds)
    fld = flds{h1};
    
    if length(pdata.(fld).rawDataFNs) == 0
        continue;
    end
    
    if ~isfield(pdata.(fld), 'srt_nLPCs')
        bFoundMissing = 1;
        break;
    end

    for h2 = 1 : numel(pdata.(fld).srt_nLPCs)
        if pdata.(fld).bDiscard(h2)
            continue;
        end

        if pdata.(fld).rating(h2) == 0
            continue;
        end

        if isempty(pdata.(fld).srt_nLPCs{h2})
            bFoundMissing = 1;
            break;
        else
            a_nLPC_lst = [a_nLPC_lst; pdata.(fld).srt_nLPCs{h2}];
        end
    end            
end

if bFoundMissing
    fprintf(1, 'WARNING: This action cannot be taken until auto nLPC has not been run on all trials.\n');
    return
end

if ~isfield(pdata, 'nLPC_status')
    fprintf(1, 'WARNING: User nLPCs have not been overwritten by best nLPC or list-first nLPCs yet.\nCannot perform this restoring at this moment.\n');
    return
else
    if isequal(pdata.nLPC_status, 'user')
        fprintf(1, 'WARNING: User nLPCs have not been overwritten by best nLPC or list-first nLPCs yet.\nCannot perform this restoring at this moment.\n');        
        return
    end
end

fields = {'randData', 'sustData'};
for i1 = 1 : numel(fields)
    fld = fields{i1};

    pdata.(fld).nLPC = pdata.(fld).user_nLPCs; % Restore user selections
end    

pdata.nLPC_status = 'user';
save(dacacheFN, 'pdata');
fprintf(1, 'Restored user nLPCs. \npdata saved to %s\n', dacacheFN);

set(uihdls.hlist, 'Enable', 'off');
lst_str = get(uihdls.hlist, 'String');
for i1 = 1 : numel(lst_str)
    set(uihdls.hlist, 'Value', i1);
    list_cbk(uihdls.hlist, [], dacacheFN, stateFN, uihdls);
    set(uihdls.hlist, 'Enable', 'off');
    drawnow;
end
set(uihdls.hlist, 'Enable', 'on');

fprintf(1, 'Restored user nLPCs. \npdata saved to %s\n', dacacheFN);
return

%%
function set_nLPC_list_1st(hObject, eventdata, dacacheFN, stateFN, uihdls)
load(dacacheFN); % Gives pdata

flds = {'otherData', 'randData', 'sustData'};
bFoundMissing = 0;
a_nLPC_lst = [];
for h1 = 1 : numel(flds)
    fld = flds{h1};
    
    if length(pdata.(fld).rawDataFNs) == 0
        continue;
    end
    
    if ~isfield(pdata.(fld), 'srt_nLPCs')
        bFoundMissing = 1;
        break;
    end

    for h2 = 1 : numel(pdata.(fld).srt_nLPCs)
        if pdata.(fld).bDiscard(h2)
            continue;
        end

        if pdata.(fld).rating(h2) == 0
            continue;
        end

        if isempty(pdata.(fld).srt_nLPCs{h2})
            bFoundMissing = 1;
            break;
        else
            a_nLPC_lst = [a_nLPC_lst; pdata.(fld).srt_nLPCs{h2}];
        end
    end            
end

if bFoundMissing
    fprintf(2, 'ERROR: Setting nLPC to 1st in list cannot be done until auto nLPC has not been run on all trials.\n');
    return
end
    
if ~isfield(pdata, 'nLPC_status')
    pdata.nLPC_status = 'user';
else
    if isequal(pdata.nLPC_status, 'list_1st')
        fprintf(1, 'Data are already set to list-first nLPCs. No changes will be made.\n');
        return;
    end
end

fields = {'randData', 'sustData'};
for i1 = 1 : numel(fields)
    fld = fields{i1};

    if isequal(pdata.nLPC_status, 'user')
        pdata.(fld).user_nLPCs = pdata.(fld).nLPC; % Backup user selections
    end

    for i2 = 1 : numel(pdata.(fld).nLPC)
        if ~isnan(pdata.(fld).nLPC)
            if isempty(pdata.(fld).srt_nLPCs{i2})
                continue;
            end
            pdata.(fld).nLPC(i2) = pdata.(fld).srt_nLPCs{i2}(1);
        end
    end
end    

pdata.nLPC_status = 'list_1st';

save(dacacheFN, 'pdata');
fprintf(1, 'Set all nLPCs to list-first. \npdata saved to %s\n', dacacheFN);

set(uihdls.hlist, 'Enable', 'off');
lst_str = get(uihdls.hlist, 'String');
for i1 = 1 : numel(lst_str)
    set(uihdls.hlist, 'Value', i1);
    list_cbk(uihdls.hlist, [], dacacheFN, stateFN, uihdls);
    set(uihdls.hlist, 'Enable', 'off');
    drawnow;
end
set(uihdls.hlist, 'Enable', 'on');
fprintf(1, 'Set all nLPCs to list-first. \npdata saved to %s\n', dacacheFN);

return