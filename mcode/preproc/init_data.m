function [rData, exptType] = init_data(type, mainUtter, phases, expt, rawDataDir, subjID)
rData.rawDataFNs = cell(1,0);
rData.phases = cell(1,0);
rData.blockNums = [];
rData.trialNums = [];
rData.words = cell(1,0);
rData.datenums = [];
rData.bRhythm = [];
rData.pertType = [];
rData.noiseMasked = []; % 0 / 1 value

%% Determine if this is a behav or MRI experiment
if isempty(type)
    if isfield(expt.script.run1.rep1, 'pertType')
        exptType = 'behav';
    else
        exptType = 'fMRI';
    end
else
    exptType = type;
end

%% Additional optinal fields in rData

%%

% sustData.rawDataFNs=cell(1,0);
% sustData.phases=cell(1,0);
% sustData.blockNums=[];
% sustData.trialNums=[];
% sustData.words=cell(1,0);
% sustData.datenums=[];
for i1 = 1 : numel(phases)
    t_phase = phases{i1};
    if isdir(fullfile(rawDataDir, subjID, t_phase))
        d1 = dir(fullfile(rawDataDir, subjID, t_phase,'rep*'));
        for i2 = 1 : numel(d1)
            t_dir = fullfile(rawDataDir,subjID,t_phase,d1(i2).name);
            
            d2_1 = dir(fullfile(t_dir,'trial-*-1.mat'));
            d2_2 = dir(fullfile(t_dir,'trial-*-2.mat'));
            d2_3 = dir(fullfile(t_dir,'trial-*-3.mat'));
            d2_4 = dir(fullfile(t_dir,'trial-*-4.mat'));
            
            d2 = [d2_1; d2_2; d2_3; d2_4];
            
            for i3 = 1 : numel(d2)
                t_fn=fullfile(t_dir, d2(i3).name);
                load(t_fn);     % gives data
                               
                if (isequal(exptType, 'behav') || isequal(exptType, 'rand-twarp-fmt')) && ~isequal(data.params.name, mainUtter)
                    continue;
                end
                
                rData.rawDataFNs{end+1} = t_fn;
                rData.phases{end+1} = t_phase;
                rData.blockNums(end+1) = str2num(strrep(d1(i2).name, 'rep', ''));
                rData.trialNums(end+1) = str2num(strrep(strrep(strrep(d2(i3).name, 'trial-', ''), '-1.mat', ''), '-2.mat', ''));
                rData.words{end+1} = data.params.name;
                rData.datenums(end+1) = datenum(data.timeStamp);
                
                if isequal(exptType, 'behav') || isequal(exptType, 'fMRI') || ...
                   isequal(exptType, 'rand-twarp-fmt') || isequal(exptType, 'rand-RHY-fmri')
                    rData.bRhythm(end + 1) = isequal(d2(i3).name(end - 5 : end), '-2.mat');
                else
                    rData.bRhythm(end + 1) = 0;
                end
                
                if isequal(exptType, 'sust-fmt')
                    t_noiseMasked = (data.params.trialType == 2);
                else
                    t_noiseMasked = 0;
                end
                rData.noiseMasked(end + 1) = t_noiseMasked;
                
                if isequal(exptType, 'behav') || isequal(exptType, 'rand-twarp-fmt')                   
                    t_pertType = expt.script.(rData.phases{end}).(['rep', num2str(rData.blockNums(end))]).pertType(rData.trialNums(end));
                elseif isequal(exptType, 'sust-fmt')
                    t_pertType = (isequal(t_phase, 'ramp') | isequal(t_phase, 'stay')) & ~t_noiseMasked;
                else
                    t_pertType = 0;
                end
                
                if ~isequal(data.params.name, expt.script.(rData.phases{end}).(['rep', num2str(rData.blockNums(end))]).word{rData.trialNums(end)})
                    fprintf(2, 'WARNING: mismatch in word between data and expt in file %s\n', t_fn);
                end

                if (isequal(exptType, 'behav') || isequal(exptType, 'rand-twarp-fmt')) && (t_pertType < 0 || t_pertType > 3)
                    fprintf(2, 'WARNING: Unexpected pertType (%d) in trial %s\n', t_pertType, t_fn);
                end
                
%                 if t_pertType == 1 % DEBUG
%                     pause(0);
%                 elseif t_pertType == 2 % DEBUG
%                     pause(0);
%                     % show_spectrogram(data.signalIn, 16e3); show_spectrogram(data.signalOut, 16e3);
%                 else
%                     pause(0);
%                 end

                rData.pertType(end + 1) = t_pertType;
                
                
                
                if isequal(type, 'rand')
                    t_fn = fullfile(t_dir, d2(i3).name);
                    load(t_fn);
                    
                    if data.params.bShift == 0
                        rData.pertType(end + 1) = 0;
                    else
                        if data.params.pertPhi(1) > 0
                            rData.pertType(end + 1) = 1; % higher: F1 down, F2 up
                        else
                            rData.pertType(end + 1) = -1; % lower: F1 up, F2 down
                        end
                    end
                end
                
            end
        end
    end
end

%% Data fields
% ## Second column: isCell ## %
if isequal(exptType, 'behav') || isequal(exptType, 'rand-twarp-fmt')
    dataFlds = {'rmsThresh',  0; 
                'fn1',        0;
                'fn2',        0;
                'aFact',      0;
                'bFact',      0;
                'gFact',      0;
                'bCepsLift',  0;
                'cepsWinWidth', 0;
                'nLPC',       0;
                'vowelOnset',     0;
                'vowelEnd',       0;
                'vowelOnsetIdx',  0;
                'vowelEndIdx',    0;
                'f1Traj',         1;
                'f2Traj',         1;
                'prodF1',         0;
                'prodF2',         0;
                'prodF1_LB',      0;
                'prodF2_LB',      0;
                'prodF1_shira',   0;
                'prodF2_shira',   0;
                'prodF1_mnlBound',    0;
                'prodF2_mnlBound',    0;
                'audF1',      0;
                'audF2',      0;
                'sigRMS',     1;
                'sOnsetTime', 0;
                't1OnsetTime', 0;          
                'dOnsetTime', 0;
                'b1OnsetTime', 0;
                'gOnsetTime', 0;
                'b2OnsetTime', 0;
                't2OnsetTime', 0; % [t] in "to"
                'p1OnsetTime', 0;
                'p2OnsetTime', 0;
                'bRhythmError', 0;
                'fluencyCode', 1; % [] - fluent
                'bDiscard',   0;
                'bRMSGood', 0;
                'bSpeedGood', 0;
                'bASROkay', 0;
                'bOSTOkay', 0;
                'bPertOkay', 0;
                'rating', 0;
                'comments', 1;
                'fluency_comments', 1};
elseif isequal(exptType, 'sust-fmt')
    dataFlds = {'rmsThresh',  0; 
                'fn1',        0;
                'fn2',        0;
                'aFact',      0;
                'bFact',      0;
                'gFact',      0;
                'bCepsLift',  0;
                'cepsWinWidth', 0;
                'nLPC',       0;
                'vowelOnset',     0;
                'vowelEnd',       0;
                'vowelOnsetIdx',  0;
                'vowelEndIdx',    0;
                'f1Traj',         1;
                'f2Traj',         1;
                'prodF1',         0;
                'prodF2',         0;
                'prodF1_LB',      0;
                'prodF2_LB',      0;
                'prodF1_shira',   0;
                'prodF2_shira',   0;
                'prodF1_mnlBound',    0;
                'prodF2_mnlBound',    0;
                'audF1',      0;
                'audF2',      0;
                'sigRMS',     1;
                'fluencyCode', 1; % [] - fluent
                'bDiscard',   0;
                'bRMSGood', 0;
                'bSpeedGood', 0;
                'bASROkay', 0;                
                'bPertOkay', 0;
                'rating', 0;
                'comments', 1};
else
    error_log(sprintf('%s: encountered currently unsupported exptType: %s', ...
                     mfilename, exptType));
end
          

for i1 = 1 : size(dataFlds, 1)
    fld = dataFlds{i1, 1};
    isc = dataFlds{i1, 2};
    
    if isc == 1
        rData.(fld) = cell(size(rData.rawDataFNs));
    else
        rData.(fld) = nan(size(rData.rawDataFNs));
    end
end

rData.comments = cell(size(rData.rawDataFNs));
rData.fluency_comments = cell(size(rData.rawDataFNs));

rData.bPertOkay = nan(size(rData.rawDataFNs));

return