function pdata1 = updateDataUI(uihdls, pdata, dataFld, idx_trial, state, tridx, varargin)
%% Input arguments:
% tridx - position in the UI trial list
DEFAULT_NLPC = 13;

colors.R = [0, 0, 1];
colors.N = [0, 0.5, 0];
colors.black = [0, 0, 0];

%% CONFIG
[marks, marksDesc] = get_preproc_marks();

lwMarks = 1.5;

FmtShiftStat0 = 5;
FmtShiftStat1 = 9;

asrOutFNs = {'julian_stdout.txt', 'asrout'};

%% External config
daSettings = data_analysis_settings(uihdls.exptType);
POST_EXPT_RMS_THRESH = daSettings.POST_EXPT_RMS_THRESH;

%% Data analysis configurations
mvaWinWidth = 21;     % 21 * 1.333 = 28 (ms)
fineParseWin = 100e-3;	% sec

ylim=[0,5000];
rmsOneSide=0.01;  % Unit: sec
rmsLBRatio=0.75;
shiraOneSide=0.025; % Unit: sec

%%
FOCUS_AND_RELABEL = 0;

if ~isempty(fsic(varargin, 'focus'))
    FOCUS_AND_RELABEL = 1;
end

%% -- Main screening process --
bIsRHY = ~isfield(uihdls, 'exptType') || isequal(uihdls.exptType, 'behav') || isequal(uihdls.exptType, 'fMRI') || ...
         isequal(uihdls.exptType, 'rand-twarp-fmt') || isequal(uihdls.exptType, 'rand-RHY-fmri');

if ~isempty(tridx)
    this_utter.phase = state.trialList.phase{tridx};
    if iscell(state.trialList.block(tridx))
        this_utter.blockNum=state.trialList.block{tridx};
    else
        this_utter.blockNum=state.trialList.block(tridx);
    end
    % this_utter.trialNum=state.trialList.trialN(tridx);

    [ret, hostName]=system('hostname');
    rawfn = getRawFN_(state.rawDataDir,state.trialList.fn{tridx});
    if ~isequal(lower(deblank(hostName)), 'smcg_w510')
        rawfn = strrep(rawfn, 'E:', 'D:');
    else
        rawfn = strrep(rawfn, 'D:', 'E:');
    end
end

load(rawfn);	% gives data
dataOrig=data;

sigIn=data.signalIn;
fs=data.params.sr;

if ~isempty(fsic(varargin, 'fromList'))
    if get(uihdls.rb_alwaysPlaySigIn, 'Value') == 1
        soundsc(sigIn, fs);
    end
end

this_utter.rmsThresh_orig = POST_EXPT_RMS_THRESH;
this_utter.fn1_orig = data.params.fn1;
this_utter.fn2_orig = data.params.fn2;
this_utter.aFact_orig = data.params.aFact;
this_utter.bFact_orig = data.params.bFact;
this_utter.gFact_orig = data.params.gFact;
this_utter.bCepsLift_orig = data.params.bCepsLift;
this_utter.cepsWinWidth_orig = data.params.cepsWinWidth;
this_utter.nLPC_orig = data.params.nLPC;

if ~isfield(state, 'exptType') || isequal(state.exptType, 'behav')
    this_utter.bRmsGood = data.bRmsGood;
    this_utter.bSpeedGood = data.bSpeedGood;
end

if isnan(pdata.(dataFld).rmsThresh(idx_trial))
%     this_utter.rmsThresh = data.params.rmsThresh;
    this_utter.rmsThresh = POST_EXPT_RMS_THRESH;
    this_utter.nLPC = data.params.nLPC;
    this_utter.fn1=data.params.fn1;
    this_utter.fn2=data.params.fn2;
    this_utter.aFact=data.params.aFact;
    this_utter.bFact=data.params.bFact;
    this_utter.gFact=data.params.gFact;
    this_utter.bCepsLift = data.params.bCepsLift;
    this_utter.cepsWinWidth = data.params.cepsWinWidth;
    
else
%     this_utter.rmsThresh = str2double(get(uihdls.edit_rmsThresh, 'String'));
    this_utter.rmsThresh = POST_EXPT_RMS_THRESH;
    this_utter.nLPC = str2num(get(uihdls.edit_nLPC, 'String'));
    this_utter.fn1 = str2double(get(uihdls.edit_fn1, 'String'));
    this_utter.fn2 = str2double(get(uihdls.edit_fn2, 'String'));
    this_utter.aFact = str2double(get(uihdls.edit_aFact, 'String'));
    this_utter.bFact = str2double(get(uihdls.edit_bFact, 'String'));
    this_utter.gFact = str2double(get(uihdls.edit_gFact, 'String'));
    this_utter.bCepsLift = str2num(get(uihdls.edit_bCepsLift, 'String'));
    this_utter.cepsWinWidth = str2num(get(uihdls.edit_cepsWinWidth, 'String'));
end

% --- Check the value of nLPC ---
if this_utter.nLPC > 19 || this_utter.nLPC < 5
    resp = msgbox(sprintf('WARNING: nLPC out of range. Force it to be the default: %d\n', DEFAULT_NLPC), 'nLPC value error', 'modal');
    set(uihdls.edit_nLPC, 'String', num2str(DEFAULT_NLPC));
    this_utter.nLPC = DEFAULT_NLPC;
end

% --- Check if pcf file exists --- %
if isequal(uihdls.exptType, 'sust-fmt');
    [dirName, ~] = fileparts(rawfn);
    
    pcf_d = dir(fullfile(dirName, 'fmt.pcf'));
    if length(pcf_d) == 1
        pcf_fn = fullfile(dirName, pcf_d(1).name);
        AudapterIO('pcf', pcf_fn);
    end
end

if state.bFirstTime==1
    data=reprocData(dataOrig, 'rmsThresh',this_utter.rmsThresh, 'fn1',this_utter.fn1,'fn2',this_utter.fn2,...
                    'aFact',this_utter.aFact,'bFact',this_utter.bFact, 'gFact', this_utter.gFact, 'nLPC', this_utter.nLPC, ...
                    'bCepsLift', this_utter.bCepsLift, 'cepsWinWidth', this_utter.cepsWinWidth, ...
                    'rmsRatioThresh', daSettings.POST_EXPT_RMS_RATIO_THRESH);
    state.bFirstTime=0;
end

% if ~isnan(state.persist_rmsThresh)
%     this_utter.rmsThresh = persist_rmsThresh;
% end

for h = 1 : 1
    data=reprocData(dataOrig,'rmsThresh',this_utter.rmsThresh,'fn1',this_utter.fn1,'fn2',this_utter.fn2,...
                    'aFact',this_utter.aFact,'bFact',this_utter.bFact,'gFact',this_utter.gFact, 'nLPC', this_utter.nLPC, ...
                    'bCepsLift', this_utter.bCepsLift, 'cepsWinWidth', this_utter.cepsWinWidth, ...
                    'rmsRatioThresh', daSettings.POST_EXPT_RMS_RATIO_THRESH);
end

f1v=data.fmts(:,1);
f2v=data.fmts(:,2);
sf1v=data.sfmts(:,1);
sf2v=data.sfmts(:,2);
sigRMS=data.rms(:,1);
f1v=mva_nz(f1v, mvaWinWidth, 'Hamming');
f2v=mva_nz(f2v, mvaWinWidth, 'Hamming');

%% --- Load ASR data --- %%
%% 
frameDur=data.params.frameLen/data.params.sr;
taxis1=0:(frameDur):(frameDur*(length(f1v)-1));

rawDataFN = state.trialList.fn{tridx};
[fpath, fname] = fileparts(rawDataFN);
asrDir = fullfile(fpath, [fname, '_asr']);

if isdir(asrDir)
    wavFN = fullfile(asrDir, 'speech.wav');
    
    bFoundASROut = 0;
    for j1 = 1 : numel(asrOutFNs)
        julianOut = fullfile(asrDir, asrOutFNs{j1});
        if isfile(julianOut)
            bFoundASROut = 1;
            break;
        end
    end
    
    if ~bFoundASROut
        error_log('Cannot find ASR output file in ASR directory: %s', asrDir);
    end
    
    check_file(wavFN);
    pa = parse_asr_out(julianOut, wavFN);
    
    if pa.nphns > 2
        ts1_0 = pa.tbeg(2);
        ts2_0 = pa.tbeg(end);
        
        ts1 = ts1_0 - 0.1 * (ts2_0 - ts1_0);
        ts2 = ts2_0 + 0.1 * (ts2_0 - ts1_0);
        
        iv1 = round(ts1 / frameDur);
        iv2 = round(ts2 / frameDur);
        
        if iv1 < 1
            iv1 = 1;
        end
        
        if iv2 > length(taxis1)
            iv2 = length(taxis1);
        end
    else
        fprintf(1, 'WARNING: ASR results appears to be erroneous in trial %s', rawDataFn);
        iv1 = 1;
        iv2 = length(taxis1);
    end
else
    
end


%% --- Find the first vowel --- %%
%--- (assuming the first vowel is the vowel in question) ---%
if isfield(uihdls, 'exptType') && isequal(uihdls.exptType, 'sust-fmt');
    if isempty(pa)
        info_log(sprintf('ASR failed on trial: %s.', rawfn), '-warn');

        vowelOnset = NaN;
        vowelEnd = NaN;
        vowelOnsetIdx = NaN;
        vowelEndIdx = NaN;
    else
        bFoundVowel = 0;
        for pidx = 1 : numel(pa.phones)
            if is_vowel_cmu(pa.phones{pidx})
                bFoundVowel = 1;
                break;
            end
        end

        if ~bFoundVowel
            info_log(sprintf('Cannot find a vowel in the ASR result from trial: %s.', rawfn), '-warn');

            vowelOnset = NaN;
            vowelEnd = NaN;
            vowelOnsetIdx = NaN;
            vowelEndIdx = NaN;
        else
            vowelOnset = pa.tbeg(pidx);
            vowelEnd = pa.tend(pidx);
            vowelOnsetIdx = round(pa.tbeg(pidx) / frameDur);
            vowelEndIdx = round(pa.tend(pidx) / frameDur);
        end
    end
end
            
%%
if ~isempty(iv1)
    this_utter.iv1=iv1;
else
    this_utter.iv1=NaN;
end
if ~isempty(iv2)
    this_utter.iv2=iv2;
else
    this_utter.iv2=NaN;
end



h1 = uihdls.haxes1;
h2 = uihdls.haxes2;

% if isequal(state.trialList.phase{tridx},'ramp') || isequal(state.trialList.phase{tridx},'stay') || isequal(state.trialList.phase{tridx},'stay2')
%     pertStr='pert';
% else
%     pertStr='none';
% end
if state.trialList.pertType(tridx) == 0
    pertStr = 'noPert';
elseif state.trialList.pertType(tridx) == 1
    pertStr = 'F1Up';
elseif state.trialList.pertType(tridx) == 2
    pertStr = 'Decel';
else
    error('Unexpected pertType: %d', state.trialList.pertType(tridx));
end

%     pertStr=trialList.pert{tridx};

% if isequal(uihdls.exptType, 'sust-fmt')
%     if isempty(find(f1v>0))
%         this_utter.pertStr=pertStr;
%         this_utter.rawDataFN=state.trialList.fn{tridx};
% 
%         this_utter.bDiscard=1;    
% 
%         this_utter.rating=0;
%         if ~isnan(pdata.(dataFld).rating(idx_trial))
%             this_utter.rating = pdata.(dataFld).rating(idx_trial);
%         end
% 
%     %     this_utter.comments=''; % SCai (01/13/2013)
%         if ~isempty(pdata.(dataFld).comments{idx_trial})
%             this_utter.comments = pdata.(dataFld).comments{idx_trial};
%         else
%             this_utter.comments = '';
%         end
% 
%         this_utter.prodF1=NaN;
%         this_utter.prodF2=NaN;
%         this_utter.audF1=NaN;
%         this_utter.audF2=NaN;
% 
%         if ~isequal(data.params.name,pdata.(dataFld).words{idx_trial})
%             fprintf('WARNING: word mismatch!\n');
%         end
%         pdata.(dataFld).rmsThresh(idx_trial)=this_utter.rmsThresh;
%         pdata.(dataFld).fn1(idx_trial)=this_utter.fn1;
%         pdata.(dataFld).fn2(idx_trial)=this_utter.fn2;
%         pdata.(dataFld).aFact(idx_trial)=this_utter.aFact;
%         pdata.(dataFld).bFact(idx_trial)=this_utter.bFact;
%         pdata.(dataFld).gFact(idx_trial)=this_utter.gFact;
%         pdata.(dataFld).bCepsLift(idx_trial)=this_utter.bCepsLift;
%         pdata.(dataFld).cepsWinWidth(idx_trial)=this_utter.cepsWinWidth;
%         pdata.(dataFld).nLPC(idx_trial)=this_utter.nLPC;
% 
%         pdata.(dataFld).prodF1(idx_trial)=this_utter.prodF1;
%         pdata.(dataFld).prodF2(idx_trial)=this_utter.prodF2;
%         pdata.(dataFld).audF1(idx_trial)=this_utter.audF1;
%         pdata.(dataFld).audF2(idx_trial)=this_utter.audF2;
%         pdata.(dataFld).traj_F1{idx_trial}=[];
%         pdata.(dataFld).traj_F2{idx_trial}=[];
%         pdata.(dataFld).sigRMS{idx_trial}=[];
%         pdata.(dataFld).iv1(idx_trial)=NaN;
%         pdata.(dataFld).iv2(idx_trial)=NaN;
%         pdata.(dataFld).bDiscard(idx_trial) = this_utter.bDiscard;
%         pdata.(dataFld).rating(idx_trial) = this_utter.rating;
%         pdata.(dataFld).comments{idx_trial} = this_utter.comments;
% 
%         set(gcf, 'CurrentAxes', h1);    
%     %     title(sprintf('%s - Rep #%d - Trial #%d: %s: parsing failed --> discarded',strrep(this_utter.rawDataFN,'\','/'),...
%     %         this_utter.blockNum,this_utter.trialNum,this_utter.pertStr),...
%     %         'FontWeight','Bold');
% 
%         title(sprintf('%s: parsing failed --> discarded', strrep(strrep(this_utter.rawDataFN,'\','/'), '_', '\_')), ...
%             'FontWeight','Bold');
%     %     coord=ginput(1);
% 
%         pdata1 = pdata;
% 
% 
%         return;
%     else
%         
%     end
% end

%     if ~isempty(find(data.sentStat==6))
%         xlim=[taxis1(min(find(data.sentStat==1)))-0.2,taxis1(min(find(data.sentStat==6)))+0.8];
%     else
xlim=[taxis1(iv1), taxis1(min([iv2, length(taxis1)]))];
%     end

this_utter.pertStr=pertStr;
this_utter.rawDataFN=state.trialList.fn{tridx};
this_utter.bDiscard=0;

%     idx_v1=round(iv1+0.4*(iv2-iv1));
%     idx_v2=round(iv1+0.6*(iv2-iv1));

% ------------ Compute the three F1/F2 averages ------------ %
t_rms=data.rms(iv1:iv2);
t_rms=mva_nz(t_rms,mvaWinWidth,'Hamming');
[max_rms,idx_max_rms]=max(t_rms);
rms_lb=max_rms*rmsLBRatio;
idx_v1=max([iv1,round(iv1+idx_max_rms-1-rmsOneSide/frameDur)]);
idx_v2=min([iv2,round(iv1+idx_max_rms-1+rmsOneSide/frameDur)]);
idx_lb_v1=iv1+min(find(t_rms>rms_lb))-1;
idx_lb_v2=iv1+max(find(t_rms>rms_lb))-1;

if ~isnan(vowelOnsetIdx) && ~isnan(vowelEndIdx)
    this_utter.prodF1 = nanmean(f1v(vowelOnsetIdx : vowelEndIdx));
    this_utter.prodF2 = nanmean(f2v(vowelOnsetIdx : vowelEndIdx));
else
    this_utter.prodF1 = NaN;
    this_utter.prodF2 = NaN;
end

this_utter.prodF1_LB=nanmean(f1v(idx_lb_v1:idx_lb_v2));
this_utter.prodF2_LB=nanmean(f2v(idx_lb_v1:idx_lb_v2));

% -- Shira's method --
idx_max_rms = idx_max_rms + iv1 - 1;
t_rms = mva_nz(data.rms(:, 1), mvaWinWidth, 'Hamming');
rms_lb_shira = max_rms * 0.4;
for k2 = idx_max_rms : -1 : 1
    if t_rms(k2) < rms_lb_shira
        break;
    end
end
idx_shira_v1 = k2;

for k2 = idx_max_rms : 1 : length(t_rms)
    if t_rms(k2) < rms_lb_shira
        break;
    end
end
idx_shira_v2 = k2;

idx_shira_mid = (idx_shira_v1 + idx_shira_v2) / 2;
idx_shira_v1 = round(idx_shira_mid - shiraOneSide / frameDur);
idx_shira_v2 = round(idx_shira_mid + shiraOneSide / frameDur);

t_f1v = f1v(idx_shira_v1 : idx_shira_v2);
t_f2v = f2v(idx_shira_v1 : idx_shira_v2);    
this_utter.prodF1_shira = nanmean(t_f1v(t_f1v > 0));
this_utter.prodF2_shira = nanmean(t_f2v(t_f2v > 0));
this_utter.rms_lb_shira = rms_lb_shira;
this_utter.idx_shira_v1 = idx_shira_v1;
this_utter.idx_shira_v2 = idx_shira_v2;
% -- ~Shira's method --
% ------------ ~Compute the three F1/F2 averages ------------ %

this_utter.idx_mnlBound_1 = NaN;
this_utter.idx_mnlBound_2 = NaN;
this_utter.prodF1_mnlBound = NaN;
this_utter.prodF2_mnlBound = NaN;



this_utter.idx_v1=idx_v1;
this_utter.idx_v2=idx_v2;
this_utter.idx_lb_v1=idx_lb_v1;
this_utter.idx_lb_v2=idx_lb_v2;
if isequal(pertStr,'none')
    this_utter.audF1=this_utter.prodF1;
    this_utter.audF2=this_utter.prodF2;
else
    this_utter.audF1=nanmean(sf1v(idx_v1:idx_v2));
    this_utter.audF2=nanmean(sf2v(idx_v1:idx_v2));
end

% this_utter.vowelOnset = NaN;
% this_utter.vowelEnd = NaN;
% this_utter.vowelOnsetIdx = NaN;
% this_utter.vowelEndIdx = NaN;
this_utter.f1Traj = [];
this_utter.f2Traj = [];

this_utter.rating = pdata.(dataFld).rating(idx_trial);
this_utter.comments = pdata.(dataFld).comments{idx_trial};

if bIsRHY
    if state.trialList.bRhythm(tridx) == 1
        rhythmLet = 'R';
        titleClr = colors.R;
    else
        rhythmLet = 'N';
        titleClr = colors.N;
    end
else
    rhythmLet = 'N';
    titleClr = colors.black;
end

if ~isfield(state.trialList, 'noiseMasked')
    maskStr = 'noMask';
elseif state.trialList.noiseMasked(tridx) == 1
    maskStr = 'masked';
else
    maskStr = 'noMask';
end

if bIsRHY
    t_title = sprintf('Trial #%d / %d - [%s] %s  (solid: rms LB; dashed: rms-peak-window; dotted: Shira''s method) (randomized order)', ...
                      tridx, numel(state.trialList.fn), rhythmLet, state.trialList.word{tridx});
elseif isequal(uihdls.exptType, 'sust-fmt')
    t_title = sprintf('Trial #%d / %d (in rand. order) - [%s] %s  (Black vertical lines: solid: rms LB; dot-dashed: rms peak; dotted: Katseff method) (randomized order)', ...
                      tridx, numel(state.trialList.fn), maskStr, state.trialList.word{tridx});
end
              
%%

f1v=data.fmts(:,1);
f2v=data.fmts(:,2);
f1v=mva_nz(f1v,mvaWinWidth,'Hamming');
f2v=mva_nz(f2v,mvaWinWidth,'Hamming');
sf1v=data.sfmts(:,1);
sf2v=data.sfmts(:,2);
sigRMS=data.rms(:,1);

% [j1,j2,foo1,foo2,iv1,iv2]=getFmtPlotBounds(f1v,f2v);

if ~isempty(iv1)
    this_utter.iv1=iv1;
else
    this_utter.iv1=NaN;
end
if ~isempty(iv2)
    this_utter.iv2=iv2;
else
    this_utter.iv2=NaN;
end
if (~isempty(iv1) && ~isempty(iv2) && ~isnan(vowelOnsetIdx) && ~isnan(vowelEndIdx))
    this_utter.traj_F1 = f1v(vowelOnsetIdx : vowelEndIdx);
    this_utter.traj_F2 = f2v(vowelOnsetIdx : vowelEndIdx);
    this_utter.sigRMS = sigRMS(vowelOnsetIdx : vowelEndIdx);
else
    this_utter.traj_F1 = [];
    this_utter.traj_F2 = [];
    this_utter.sigRMS = [];
end



xlim = [taxis1(iv1), taxis1(iv2)];
% xrange = range(xlim);
% xlim(1) = xlim(1) - 0.5 * xrange;
% xlim(2) = xlim(2) + 0.5 * xrange;

set(gcf,'CurrentAxes',h1);
cla;
[s,f,t]=spectrogram(sigIn,128,96,1024,fs);
imagesc(t,f,10*log10(abs(s))); hold on;
axis xy;
hold on;

plot(taxis1,f1v,'w-','LineWidth',1);
hold on;
plot(taxis1,f2v,'w-','LineWidth',1);

if range(xlim) == 0
    xlim(2) = xlim(2) + 0.05;
end

set(gca,'YLim',ylim,'XLim',xlim);
zdat = guidata(uihdls.haxes1);
if isempty(zdat)
    zdat = struct;
end
zdat.tmin = taxis1(1);
zdat.tmax = taxis1(end);
zdat.currXLim = xlim;
zdat.defXLim = xlim;
guidata(uihdls.haxes1, zdat);

plot_phn_align(pa, '--color', daSettings.PHN_ALIGN_CLR);


% --- Plot OST stat --- %
if isequal(state.trialList.phase{tridx}(1 : 3), 'run')
    plot(taxis1, dataOrig.ost_stat * 250, 'b-');
    
    ys = get(gca, 'YLim');
    if ~isempty(find(dataOrig.ost_stat == FmtShiftStat0, 1))
        plot(repmat(taxis1(find(dataOrig.ost_stat == FmtShiftStat0, 1)), 1, 2), ys, 'b--');
    end

    if ~isempty(find(dataOrig.ost_stat == FmtShiftStat1 + 1, 1))
        plot(repmat(taxis1(find(dataOrig.ost_stat == FmtShiftStat1 + 1, 1)), 1, 2), ys, 'b-');
    end
else
    ys = get(gca, 'YLim');
    plot(xlim, repmat(ys(2) - 0.1 * range(ys), 1, 2), 'b-');
end

%         xlabel('Time (s)');
ylabel('Frequency (Hz)');

%         idx_v1=round(iv1+0.4*(iv2-iv1));
%         idx_v2=round(iv1+0.6*(iv2-iv1));
t_rms=data.rms(iv1:iv2);
t_rms=mva_nz(t_rms,mvaWinWidth,'Hamming');
[max_rms,idx_max_rms]=max(t_rms);
rms_lb=max_rms*rmsLBRatio;
idx_v1=max([iv1,round(iv1+idx_max_rms-1-rmsOneSide/frameDur)]);
idx_v2=min([iv2,round(iv1+idx_max_rms-1+rmsOneSide/frameDur)]);
idx_lb_v1=iv1+min(find(t_rms>rms_lb))-1;
idx_lb_v2=iv1+max(find(t_rms>rms_lb))-1;
this_utter.prodF1=nanmean(f1v(idx_v1:idx_v2));
this_utter.prodF2=nanmean(f2v(idx_v1:idx_v2));
this_utter.prodF1_LB=nanmean(f1v(idx_lb_v1:idx_lb_v2));
this_utter.prodF2_LB=nanmean(f2v(idx_lb_v1:idx_lb_v2));
this_utter.idx_v1=idx_v1;
this_utter.idx_v2=idx_v2;
this_utter.idx_lb_v1=idx_lb_v1;
this_utter.idx_lb_v2=idx_lb_v2;

% -- Shira's method --
idx_max_rms = idx_max_rms + iv1 - 1;
t_rms = mva_nz(data.rms(:, 1), mvaWinWidth, 'Hamming');
rms_lb_shira = max_rms * 0.4;
for k2 = idx_max_rms : -1 : 1
    if t_rms(k2) < rms_lb_shira
        break;
    end
end
idx_shira_v1 = k2;

for k2 = idx_max_rms : 1 : length(t_rms)
    if t_rms(k2) < rms_lb_shira
        break;
    end
end
idx_shira_v2 = k2;

idx_shira_mid = (idx_shira_v1 + idx_shira_v2) / 2;
idx_shira_v1 = round(idx_shira_mid - shiraOneSide / frameDur);
idx_shira_v2 = round(idx_shira_mid + shiraOneSide / frameDur);

t_f1v = f1v(idx_shira_v1 : idx_shira_v2);
t_f2v = f2v(idx_shira_v1 : idx_shira_v2);    
this_utter.prodF1_shira = nanmean(t_f1v(t_f1v > 0));
this_utter.prodF2_shira = nanmean(t_f2v(t_f2v > 0));
this_utter.rms_lb_shira = rms_lb_shira;
this_utter.idx_shira_v1 = idx_shira_v1;
this_utter.idx_shira_v2 = idx_shira_v2;
% -- ~Shira's method --

if bIsRHY
    % --- Manually set the key consonant land marks --- %
    bDoMarks = get(uihdls.rb_doMarks, 'Value');

    bMarksDone = 1;
    for n = 1 : numel(marks)
        t_mark = marks{n};

        if isnan(pdata.(dataFld).(t_mark)(idx_trial))
            bMarksDone = 0;
            break;
        end
    end

    ys = get(gca, 'YLim');
    if bMarksDone == 0 && bDoMarks == 1
        if FOCUS_AND_RELABEL
            set(gca, 'XLim', [taxis1(1), taxis1(end)]);

            bIntervalOkay = 0;
            while ~bIntervalOkay
                title('Click at the beginning of the focus interval...', ...
                      'Color', [0, 0.5, 0]);
                coord1 = ginput(1);
                title('Click at the end of the focus interval...', ...
                      'Color', [0, 0.5, 0]);
                coord2 = ginput(1);

                int_t0 = coord1(1);
                int_t1 = coord2(1);

                if (int_t0 < int_t1) && (int_t0 >= taxis1(1)) && (int_t1 <= taxis1(end))
                    bIntervalOkay = 1;
                else
                    bIntervalOkay = 0;
                end
            end

            set(gca, 'XLim', [int_t0, int_t1]);
        end

        lblOkay = 0;
        while ~lblOkay
            for n = 1 : numel(marks)
                t_mark = marks{n};

                title(sprintf('Set %s (%s) ...', t_mark, marksDesc{n}));
                bClickIn = 0;
                while ~bClickIn
                    coord = ginput(1);

                    bClickIn = coord(2) > ys(1) & coord(2) < ys(2);
                end                        

                this_utter.vowelOnset = coord(1);

                this_utter.(t_mark) = coord(1);            

                plot(repmat(coord(1), 1, 2), ys, 'k--', 'LineWidth', lwMarks);
            end

            lblOkay = check_marks(this_utter, marks);
        end

    else
        for n = 1 : numel(marks)
            t_mark = marks{n};
            this_utter.(t_mark) = pdata.(dataFld).(t_mark)(idx_trial);
            plot(repmat(this_utter.(t_mark), 1, 2), ys, 'k--', 'LineWidth', lwMarks);
        end

    end
end

title(t_title, 'Color', titleClr);


%% ------------ Re-compute the three F1/F2 averages ------------ %
title(t_title, 'Color', titleClr);

set(gcf,'CurrentAxes',h2);
cla;
hold on;

plot(taxis1,data.rms(:,1),'b-','LineWidth',1);        
set(gca,'XLim',xlim);
zdat = guidata(uihdls.haxes1);
zdat.currXLim = xlim;
zdat.defXLim = xlim;
guidata(uihdls.haxes1, zdat);

% ys=get(gca,'YLim');
% if ~isempty(idx_v1) && ~isempty(idx_v2)
%     plot(repmat(taxis1(idx_v1),1,2),ys,'k--');
%     plot(repmat(taxis1(idx_v2),1,2),ys,'k--');
% end
% if ~isempty(idx_lb_v1) && ~isempty(idx_lb_v2)
%     plot(repmat(taxis1(idx_lb_v1),1,2),ys,'k-');
%     plot(repmat(taxis1(idx_lb_v2),1,2),ys,'k-');
% end

% if ~isempty(idx_shira_v1) && ~isempty(idx_shira_v2)
%     plot(repmat(taxis1(idx_shira_v1),1,15),linspace(ys(1),ys(2),15),'k.');
%     plot(repmat(taxis1(idx_shira_v2),1,15),linspace(ys(1),ys(2),15),'k.');
% end
if ~isnan(this_utter.idx_mnlBound_1) && ~isempty(this_utter.idx_mnlBound_2)
    plot(repmat(taxis1(this_utter.idx_mnlBound_1),1,15),linspace(ys(1),ys(2),15),'g-');
    plot(repmat(taxis1(this_utter.idx_mnlBound_2),1,15),linspace(ys(1),ys(2),15),'g-');
end

% ylim = get(gca, 'YLim');
% plot(repmat(taxis1(idx_max_rms), 1, 2), ylim, 'k-.');

xlabel('Time (s)');

%% Vertical time lines
hs = [h1, h2];
for j0 = 1 : numel(hs)
    set(gcf,'CurrentAxes',hs(j0));
    set(gca, 'XLim', xlim);
    
    ys=get(gca,'YLim');
    if ~isempty(idx_v1) && ~isempty(idx_v2)
        plot(repmat(taxis1(idx_v1),1,2),ys,'k--');
        plot(repmat(taxis1(idx_v2),1,2),ys,'k--');
    end
    if ~isempty(idx_lb_v1) && ~isempty(idx_lb_v2)
        plot(repmat(taxis1(idx_lb_v1),1,2),ys,'k-');
        plot(repmat(taxis1(idx_lb_v2),1,2),ys,'k-');
    end

    
    plot(repmat(taxis1(idx_max_rms), 1, 2), ys, 'k-.');
end

%% Set XLim according to vowelOnsetIdx and vowelEndIdx
if isfield(this_utter, 'vowelOnsetIdx')
    t_xlim(1) = taxis1(max([1, [this_utter.vowelOnsetIdx - round(0.5 * (this_utter.vowelEndIdx - this_utter.vowelOnsetIdx))]]));
    t_xlim(2) = taxis1(min([numel(taxis1), [this_utter.vowelEndIdx + round(0.5 * (this_utter.vowelEndIdx - this_utter.vowelOnsetIdx))]]));
    
    set(gcf, 'CurrentAxes', h1);
    set(gca, 'XLim', t_xlim);        
    set(gcf, 'CurrentAxes', h2);
    set(gca, 'XLim', t_xlim);
    set(gcf, 'CurrentAxes', h1);
    
    zdat = guidata(uihdls.haxes1);
    zdat.currXLim = t_xlim;
    zdat.defXLim = t_xlim;
    guidata(uihdls.haxes1, zdat);
end

%% Display info about word correct / incorrect
% if dataOrig.resp_correct == 1
%     wcMsg = sprintf('Word marked as CORRECT during experiment');
%     wcMsgClr = 'b';
% else
%     wcMsg = sprintf('Word marked as INCORRECT during experiment');
%     wcMsgClr = 'r';
% end

% t_xs = get(gca, 'XLim');
% t_ys = get(gca, 'YLim');

% text(t_xs(1) + 0.02 * range(t_xs), t_ys(2) - 0.05 * range(t_ys), ...
%      wcMsg, 'Color', wcMsgClr);

%%
this_utter.timeStamp_analysis=clock;

if ~isequal(state.trialList.fn{tridx}, pdata.(dataFld).rawDataFNs{idx_trial})
    fprintf('ERROR: raw data file name mismatch. \n');
    return
end

if ~isequal(data.params.name,pdata.(dataFld).words{idx_trial})
    fprintf('WARNING: word mismatch!\n');
end
pdata.(dataFld).rmsThresh(idx_trial)=this_utter.rmsThresh;
pdata.(dataFld).fn1(idx_trial)=this_utter.fn1;
pdata.(dataFld).fn2(idx_trial)=this_utter.fn2;
pdata.(dataFld).aFact(idx_trial)=this_utter.aFact;
pdata.(dataFld).bFact(idx_trial)=this_utter.bFact;
pdata.(dataFld).gFact(idx_trial)=this_utter.gFact;
pdata.(dataFld).bCepsLift(idx_trial)=this_utter.bCepsLift;
pdata.(dataFld).cepsWinWidth(idx_trial)=this_utter.cepsWinWidth;
pdata.(dataFld).nLPC(idx_trial)=this_utter.nLPC;


pdata.(dataFld).f1Traj{idx_trial} = this_utter.f1Traj;
pdata.(dataFld).f2Traj{idx_trial} = this_utter.f2Traj;

if isfield(uihdls, 'exptType') && isequal(uihdls.exptType, 'sust-fmt');
    pdata.(dataFld).vowelOnset(idx_trial) = vowelOnset;
    pdata.(dataFld).vowelEnd(idx_trial) = vowelEnd;
    pdata.(dataFld).vowelOnsetIdx(idx_trial) = vowelOnsetIdx;
    pdata.(dataFld).vowelEndIdx(idx_trial) = vowelEndIdx;
    
    pdata.(dataFld).prodF1(idx_trial) = this_utter.prodF1;
    pdata.(dataFld).prodF2(idx_trial) = this_utter.prodF2;
    pdata.(dataFld).prodF1_LB(idx_trial) = this_utter.prodF1_LB;
    pdata.(dataFld).prodF2_LB(idx_trial) = this_utter.prodF2_LB;

    pdata.(dataFld).prodF1_shira(idx_trial)=this_utter.prodF1_shira;
    pdata.(dataFld).prodF2_shira(idx_trial)=this_utter.prodF2_shira;
%     pdata.(dataFld).prodF1_mnlBound(idx_trial)=this_utter.prodF1_mnlBound;
%     pdata.(dataFld).prodF2_mnlBound(idx_trial)=this_utter.prodF2_mnlBound;
end

if bIsRHY
    for n = 1 : numel(marks)
        pdata.(dataFld).(marks{n})(idx_trial) = this_utter.(marks{n});
    end
end

pdata.(dataFld).audF1(idx_trial)=this_utter.audF1;
pdata.(dataFld).audF2(idx_trial)=this_utter.audF2;
pdata.(dataFld).traj_F1{idx_trial}=this_utter.traj_F1;
pdata.(dataFld).traj_F2{idx_trial}=this_utter.traj_F2;
pdata.(dataFld).sigRMS{idx_trial}=this_utter.sigRMS;
pdata.(dataFld).iv1(idx_trial)=this_utter.iv1;
pdata.(dataFld).iv2(idx_trial)=this_utter.iv2;
pdata.(dataFld).bDiscard(idx_trial)=this_utter.bDiscard;
pdata.(dataFld).rating(idx_trial)=this_utter.rating;
pdata.(dataFld).comments{idx_trial}=this_utter.comments;

if ~isfield(state, 'exptType') || isequal(state.exptType, 'behav')
    pdata.(dataFld).bRmsGood = this_utter.bRmsGood;
    pdata.(dataFld).bSpeedGood = this_utter.bSpeedGood;
end

pdata1 = pdata;
return

%%
function bValid = check_shira_bounds(utter)
bValid = (utter.idx_shira_v1 > utter.vowelOnsetIdx) & ...
         (utter.idx_shira_v2 < utter.vowelEndIdx);

return

%%
function raw_fn=getRawFN_(expDir,fn)
[path1,fn1]=fileparts(fn);
[path2,fn2]=fileparts(path1);
[path3,fn3]=fileparts(path2);
[path4,fn4]=fileparts(path3);

raw_fn=fullfile(expDir,fn4,fn3,fn2,fn1);
if ~isequal(raw_fn(end-3:end),'.mat')
    raw_fn=[raw_fn,'.mat'];
end