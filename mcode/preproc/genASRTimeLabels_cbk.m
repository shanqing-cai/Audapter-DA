function genASRTimeLabels_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
MAX_FMT_DEV = 5;

a_nLPCs = [7, 9, 11, 13, 15];

ASR_FRAME_LEN = 0.008; % Unit: s

%%
if ~iscell(uihdls)
    load(dacacheFN);    % gives pdata
    load(stateFN);      % gives state
    
    if hObject == uihdls.bt_auto_nLPC;
        i1s = get(uihdls.hlist, 'Value'); % Individual trial
    else
        % Auto nLPC over all trials.        
        if ~isempty(find(state.stats == 0))       
            msgbox('There are some unprocessed trials. Please finish a first-pass processing of all trials (vowel bounds and auto rmsThresh) before using genASRTimeLabels', 'Unable to execute genASRTimeLabels');
            return;
        end
        
        bFoundMissing = 0;
        flds = {'mainData'};
        
        for h1 = 1 : numel(flds)
            fld = flds{h1};
            
            for h2 = 1 : numel(pdata.(fld).rating)                
                if pdata.(fld).rating(h2) == 0
                    continue;
                end
                
%                 if isnan(pdata.(fld).sOnsetTime(h2)) || ...
%                         isnan(pdata.(fld).p2OnsetTime(h2))
                if isnan(pdata.(fld).rating(h2)) || ...
                   isnan(pdata.(fld).bASROkay(h2))
                    bFoundMissing = 1;
                    break;
                end
            end            
        end
        
        if bFoundMissing
            msgbox('genASRTimeLabels cannot proceed at this time because vowel onset and end times have not been labeled in some trials', ...
                   'genASRTimeLabels cannot proceed', 'error');
            return
        end
        
        i1s = 1 : length(get(uihdls.hlist, 'String'));
    end    
else
    rawfn = uihdls{1};
    dataFld = uihdls{2};
    idx_trial = uihdls{3};
    
    dacacheFN = uihdls{4};
    stateFN = uihdls{5};
    load(dacacheFN); % gives pdata
    load(stateFN); % gives state
end

[ret, hostName]=system('hostname');

% a_srt_nLPC = nan(0, length(a_nLPCs));

if ~isfield(pdata.(fld), 'asrTBeg') || ~isfield(pdata.(fld), 'asrTBeg0')
    N = length(pdata.(fld).sOnsetTime);
    pdata.(fld).asrPhns = ({'s1', 't1', 'eh', 'd', 'iy', ...
                           'b1', 'ae', 't2', 'g', 'ey', 'v', ...
                           'b2', 'er', 'th', 't', ...
                           'uw', 'p1', 'ah', 'p2', 's2'});
	M = length(pdata.(fld).asrPhns);
    
    pdata.(fld).asrTBeg0 = nan(M, N);
    pdata.(fld).asrTBeg = nan(M, N);
end

for n = 1 : length(i1s)
    i1 = i1s(n);

    set(uihdls.hlist, 'Value', i1);
%     list_cbk([], [], dacacheFN, stateFN, uihdls);
    drawnow;
    
    idx_trial = state.trialList.allOrderN(i1);

    dataFld = 'mainData';
    
    % --- Check if this trial is discarded or has a rating of 0 ---
    if pdata.(dataFld).rating(idx_trial) == 0 || pdata.(dataFld).bDiscard(idx_trial) == 1
        fprintf(1, 'INFO: Trial #%d in the list has a rating of 0 and/or a bDiscard of 1. ASR time labels will not be extracted for this trial.\n', i1);
        continue
    end
    
    if pdata.(dataFld).bASROkay(idx_trial) == 0
        fprintf(1, 'INFO: Trial #%d in the list has a bASROkay ==  0. genASRTimeLabels will not be extracted for this trial.\n', i1);
        continue;
    end
    
    rawfn = getRawFN_(state.rawDataDir, state.trialList.fn{i1});
    
    asrDir = strrep(rawfn, '.mat', '_asr');
    check_dir(asrDir);
    julianOut = fullfile(asrDir, 'julian_stdout.txt');
    wavFN = fullfile(asrDir, 'speech.wav');
    check_file(julianOut);
    check_file(wavFN);
    pa0 = parse_asr_out(julianOut, wavFN);
    
    % --- Redo ASR, with a finer temporal resolution --- %
    tmpfn = [tempname, '.mat'];
    copyfile(rawfn, tmpfn);
    check_file(tmpfn);
    
    tmpdir = strrep(tmpfn, '.mat', '_asr');
    julianCmd = run_julian(tmpfn, 'outDir', tmpdir, 'prep', ...
                           'frameLen', ASR_FRAME_LEN);
    [so] = evalc('system(julianCmd)');
    
    t_items = splitstring(julianCmd);
    julianStdOutFN = t_items{end};
    julianWavFN = strrep(t_items{5}, 'wavlist', 'speech.wav');
    
    pa1 = parse_asr_out(julianStdOutFN, julianWavFN, 'frameLen', ASR_FRAME_LEN);
    
    delete(tmpfn);
    rmdir(tmpdir, 's');
    % --- ~Redo ASR, with a finer temporal resolution --- %
    
%     if ~isequal(lower(deblank(hostName)), 'smcg_w510')
%         rawfn = strrep(rawfn, 'E:', 'D:');
%     else
%         rawfn = strrep(rawfn, 'D:', 'E:');
%     end

%     load(rawfn);	% gives data
%     dataOrig = data;

    if length(pa0.tbeg) ~= 24
        error('Unexpected number of phones in the phone alignment results of trial %s (%d ~= %d)', ...
              rawfn, length(pa0.tbeg), length(pdata.(fld).sOnsetTime));
    end
    if length(pa1.tbeg) ~= 24
        error('Unexpected number of phones in the finer-temporal-resolution phone alignment results of trial %s (%d ~= %d)', ...
              rawfn, length(pa1.tbeg), length(pdata.(fld).sOnsetTime));
    end
    
    pdata.(fld).asrTBeg0(:, idx_trial) = pa0.tbeg(4 : 4 + length(pdata.(dataFld).asrPhns) - 1);
    pdata.(fld).asrTBeg(:, idx_trial) = pa1.tbeg(4 : 4 + length(pdata.(dataFld).asrPhns) - 1);
    
end

save(dacacheFN, 'pdata');
fprintf(1, 'Saved results to pdata file: %s\n', dacacheFN);

return