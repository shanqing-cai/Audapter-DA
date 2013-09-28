function auto_nLPC_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
MAX_FMT_DEV = 5;

a_nLPCs = [7, 9, 11, 13, 15];

%%
if ~iscell(uihdls)
    load(dacacheFN);    % gives pdata
    load(stateFN);      % gives state
    
    if hObject == uihdls.bt_auto_nLPC;
        i1s = get(uihdls.hlist, 'Value'); % Individual trial
    else
        % Auto nLPC over all trials.        
        if ~isempty(find(state.stats == 0))       
            msgbox('There are some unprocessed trials. Please finish a first-pass processing of all trials (vowel bounds and auto rmsThresh) before using Auto nLPC', 'Unable to execute Auto nLPC');
            return;
        end
        
        bFoundMissing = 0;
        flds = {'otherData', 'randData', 'sustData'};
        for h1 = 1 : numel(flds)
            fld = flds{h1};
            
            for h2 = 1 : numel(pdata.(fld).vowelOnsetIdx)
                if pdata.(fld).bDiscard(h2)
                    continue;
                end
                
                if pdata.(fld).rating(h2) == 0
                    continue;
                end
                
                if isnan(pdata.(fld).vowelOnsetIdx(h2)) || ...
                   isnan(pdata.(fld).vowelEndIdx(h2))
                    bFoundMissing = 1;
                    break;
                end
            end            
        end
        
        if bFoundMissing
            msgbox('auto nLPC all cannot proceed at this time because vowel onset and end times have not been labeled in some trials', ...
                   'auto nLPC all cannot proceed', 'error');
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

a_srt_nLPC = nan(0, length(a_nLPCs));

for n = 1 : length(i1s)
    i1 = i1s(n);

    set(uihdls.hlist, 'Value', i1);
    list_cbk([], [], dacacheFN, stateFN, uihdls);
    drawnow;
    
    idx_trial = state.trialList.allOrderN(i1);

    if isfield(state.trialList, 'isOther') && state.trialList.isOther(i1) == 1
        dataFld = 'otherData';
    elseif state.trialList.isRand(i1) == 1
        dataFld = 'randData';
    elseif state.trialList.isSust(i1) == 1
        dataFld = 'sustData';
    end
    
    % --- Check if this trial is discarded or has a rating of 0 ---
    if pdata.(dataFld).rating(idx_trial) == 0 || pdata.(dataFld).bDiscard(idx_trial) == 1
        fprintf(1, 'INFO: Trial #%d in the list has a rating of 0 and/or a bDiscard of 1. Auto nLPC will not be run on this trial.\n', i1);
        continue
    end
    
    % --- Check if auto nLPC has already been done on this trial --- 
    if isfield(pdata.(dataFld), 'srt_nLPCs')
        if ~isempty(pdata.(dataFld).srt_nLPCs{idx_trial})
            if hObject == uihdls.bt_auto_nLPC_all
                fprintf(1, 'INFO: Trial #%d in the list has already been processed by auto nLPC. Skipping it.\n', i1);
                continue;
            end
        end
    end

    rawfn = getRawFN_(state.rawDataDir, state.trialList.fn{i1});
    
    if ~isequal(lower(deblank(hostName)), 'smcg_w510')
        rawfn = strrep(rawfn, 'E:', 'D:');
    else
        rawfn = strrep(rawfn, 'D:', 'E:');
    end

    load(rawfn);	% gives data
    dataOrig = data;

    %% Make sure that the first pass is done.
    if ~isempty(find(state.stats == 0))       
        msgbox('There are some unprocessed trials. Please finish a first-pass processing of all trials (vowel bounds and auto rmsThresh) before using Auto nLPC', 'Unable to execute Auto nLPC');
        return;
    end

    %% Check to make sure the the vowel beginning/end have been marked
    vowelOnsetIdx = pdata.(dataFld).vowelOnsetIdx(idx_trial);
    vowelEndIdx = pdata.(dataFld).vowelEndIdx(idx_trial);
    
    if isnan(vowelOnsetIdx) || isnan(vowelOnsetIdx)
        fprintf(2, 'ERROR: This trial (#%d in the list) does not contain vowel onset and vowel end labels. auto_nLPC cannot proceed.\n', i1); 
    end
    
    %%    
    rmsThresh = pdata.(dataFld).rmsThresh(idx_trial);

    t_word = pdata.(dataFld).words{idx_trial};
    idxs_word = fsic(pdata.(dataFld).words, t_word);
    a_mnF1 = nanmean(pdata.(dataFld).prodF1_shira(idxs_word));
    a_mnF2 = nanmean(pdata.(dataFld).prodF2_shira(idxs_word));
    a_sdF1 = nanstd(pdata.(dataFld).prodF1_shira(idxs_word));
    a_sdF2 = nanstd(pdata.(dataFld).prodF2_shira(idxs_word));

    %% Compute the spectrogram, for later use of calculating how much energy the formant tracks capture
    sigIn = dataOrig.signalIn;
    fs = dataOrig.params.sr;
    [s,f,t]=spectrogram(sigIn, 128, 96, 1024, fs);
    t = t - t(1);
    logs = log10(abs(s));

    % figure;
    % imagesc(t,f,10*log10(abs(s))); hold on;
    % axis xy;

    %%
    % a_nLPCs = [5, 7, 9, 11, 13, 15, 17, 19];
    

    fprintf('Calculating... ');
    % avgRad = nan(numel(a_nLPCs), 2);
    fmtPower = nan(numel(a_nLPCs), 2);
    mnFmts = nan(numel(a_nLPCs), 2);
    for i1 = 1 : numel(a_nLPCs)    
        for k = 1 : 2
            t_data = reprocData(dataOrig, 'nLPC', a_nLPCs(i1), 'rmsThresh', rmsThresh);
        end

    %     avgRad(i1, :) = mean(t_data.rads(vowelOnsetIdx : vowelEndIdx, 1 : 2));

        %% Calculate the average formant frequency values
        t_f1 = t_data.fmts(vowelOnsetIdx : vowelEndIdx, 1);
        t_f2 = t_data.fmts(vowelOnsetIdx : vowelEndIdx, 2);
        mnFmts(i1, :) = [mean(t_f1(t_f1 > 0)), mean(t_f2(t_f2 > 0))];

        %% Calculate the average energy on the formant tracks    
        frameDur = t_data.params.frameLen / t_data.params.sr;
        tAxis = 0 : frameDur : frameDur * (size(t_data.fmts, 1) - 1); 

        t_fmtPower = zeros(2, 1);
        for i2 = vowelOnsetIdx : vowelEndIdx
            t_t = tAxis(i2);
            t_fmts = t_data.fmts(i2, 1 : 2);
            t_fmts = t_fmts(:);

            if t_fmts(1) == 0
                continue;
            end
            t_idx = floor(t_t / (t(2) - t(1))) + 1;
            t_frac = (t_t - t(t_idx)) / (t(2) - t(1));

            f_idx = floor(t_fmts / (f(2) - t(1))) + 1;
            f_frac = (t_fmts - f(f_idx)) / (f(2) - f(1));

            t_fmtPower = t_fmtPower + logs(f_idx, t_idx) + ...
                         t_frac * (logs(f_idx, t_idx + 1) - logs(f_idx, t_idx)) + ...
                         f_frac .* (logs(f_idx + 1, t_idx) - logs(f_idx, t_idx)) + ...
                         t_frac * f_frac .* (logs(f_idx + 1, t_idx + 1) - logs(f_idx, t_idx));
    %         t_fmtPower = t_fmtPower + logs(f_idx, t_idx);
        end

        fmtPower(i1, :) = t_fmtPower';
    end

    %% Calculate formant devation
    a_mnFmts = [a_mnF1, a_mnF2];
    a_sdFmts = [a_sdF1, a_sdF2];

    fmtDev = sqrt(mean(((mnFmts - repmat(a_mnFmts, size(mnFmts, 1), 1)) ./ repmat(a_sdFmts, size(mnFmts, 1), 1)) .^ 2, 2));
    fmtPower(fmtDev > MAX_FMT_DEV) = -bitmax;

    % avgAvgRad = mean(avgRad');
    % figure;
    % plot(a_nLPCs, avgAvgRad);

    avgFmtPower = mean(fmtPower');

    [maxFmtPower, idxMaxFmtPower] = max(avgFmtPower);
    [foo, idxSort] = sort(avgFmtPower, 'descend');
    srt_nLPCs = a_nLPCs(idxSort);
    fprintf('Best nLPC [determined by max(fmtPower)] = %d\n', a_nLPCs(idxMaxFmtPower));
    fprintf('\tFrom best to worst: ');
    disp(srt_nLPCs);

    %% Update pdata and the UI
    pdata.(dataFld).nLPC(idx_trial) = a_nLPCs(idxMaxFmtPower);
    if ~isfield(pdata.(dataFld), 'srt_nLPCs')
        pdata.(dataFld).srt_nLPCs = cell(size(pdata.(dataFld).nLPC));
    end
    pdata.(dataFld).srt_nLPCs{idx_trial} = srt_nLPCs;

    save(dacacheFN, 'pdata');

    nLPC_lst = cell(1, length(srt_nLPCs));
    for i1 = 1 : numel(srt_nLPCs)
        nLPC_lst{i1} = sprintf('%d', srt_nLPCs(i1));
    end
    set(uihdls.lst_srt_nLPCs, 'String', nLPC_lst);
    set(uihdls.lst_srt_nLPCs, 'Value', 1);
    set(uihdls.lst_srt_nLPCs, 'Enable', 'on');

    set(uihdls.edit_nLPC, 'String', sprintf('%d',  a_nLPCs(idxMaxFmtPower)));

    reproc_cbk(uihdls.bt_reproc, [], dacacheFN, stateFN, uihdls);
    drawnow;
    
    
    
end

if hObject == uihdls.bt_auto_nLPC_all
    
    
    fprintf(1, 'auto_nLPC_all done\n');
end

return