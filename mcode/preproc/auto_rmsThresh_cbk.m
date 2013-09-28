function auto_rmsThresh_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
rmsThresh_step = 0.004;
nTurns = 10; % Should alsways be odd
rmsThresh_min = 0.001;

if ~iscell(uihdls)
    i1 = get(uihdls.hlist, 'Value');
    load(dacacheFN);    % gives pdata
    load(stateFN);      % gives state

%     if isfield(state.trialList, 'isOther') && state.trialList.isOther(i1) == 1
%         dataFld = 'otherData';
%     elseif state.trialList.isRand(i1) == 1
%         dataFld = 'randData';
%     elseif state.trialList.isSust(i1) == 1
%         dataFld = 'sustData';
%     end
    dataFld = 'mainData';

    idx_trial = state.trialList.allOrderN(i1);
    
    rawfn = getRawFN_(state.rawDataDir, state.trialList.fn{i1});
else
    rawfn = uihdls{1};
    dataFld = uihdls{2};
    idx_trial = uihdls{3};
    
    dacacheFN = uihdls{4};
    stateFN = uihdls{5};
    load(dacacheFN); % gives pdata
    load(stateFN); % gives state
end


% [ret, hostName]=system('hostname');
% if ~isequal(lower(deblank(hostName)), 'smcg_w510')
%     rawfn = strrep(rawfn, 'E:', 'D:');
% else
%     rawfn = strrep(rawfn, 'D:', 'E:');
% end

load(rawfn);	% gives data

vowelOnsetIdx = pdata.(dataFld).vowelOnsetIdx(idx_trial);
vowelEndIdx = pdata.(dataFld).vowelEndIdx(idx_trial);

if isnan(vowelOnsetIdx) || isnan(vowelEndIdx)
    fprintf('WARNING: Raw file name: %s: vowelOnsetIdx and/or vowelEndIdx are NaN.\n\tThis trial has probably been discarded. Skipped it.\n', rawfn);
    return;
end

rmsThresh = data.params.rmsThresh;
dataOrig = data;

% rmsThresh = data.rms(vowelOnsetIdx, 3);

% if isempty(find(data.fmts(vowelOnsetIdx : vowelEndIdx, 1) == 0))
%     return
% end

fprintf('rmsThresh: ')
rec_rmsThresh = [];
rec_success = [];

bSuccess = 0; 
nRun = 0;
maxNRuns = 3;
while ~bSuccess % --- (01/19/2013) Deal with failures --- %
    tc = 0;
    nRun = nRun + 1;
    
    if nRun > maxNRuns
        break;
    end
    
    fprintf(1, 'Run %d: ', nRun);
    while tc < nTurns
        if mod(tc, 2) == 0
            while ~isempty(find(data.fmts(vowelOnsetIdx : vowelEndIdx, 1) == 0)) && rmsThresh > rmsThresh_min
                rmsThresh = rmsThresh - rmsThresh_step;
                data=reprocData(dataOrig, 'rmsThresh', rmsThresh);

                rec_rmsThresh(end + 1) = rmsThresh;
                rec_success(end + 1) = isempty(find(data.fmts(vowelOnsetIdx : vowelEndIdx, 1) == 0));
            end

            if rmsThresh <= rmsThresh_min
                rmsThresh = rmsThresh_min + rmsThresh_step / 2;
    %             fprintf('WARNING: auto-adjusting rmsThresh failed.');
    %             return
            end
        else
            while isempty(find(data.fmts(vowelOnsetIdx : vowelEndIdx, 1) == 0))
                rmsThresh = rmsThresh + rmsThresh_step;
                data=reprocData(dataOrig, 'rmsThresh', rmsThresh);

                rec_rmsThresh(end + 1) = rmsThresh;
                rec_success(end + 1) = isempty(find(data.fmts(vowelOnsetIdx : vowelEndIdx, 1) == 0));
            end
        end
        fprintf('%.8f, ', rmsThresh);
        rmsThresh_step = rmsThresh_step / 2;
        tc = tc + 1;
    end
    % rmsThresh = rmsThresh - rmsThresh_step * 2;
    fprintf('\n');
    
    round_rmsThresh = str2double(sprintf('%.8f', rmsThresh));
    data=reprocData(dataOrig, 'rmsThresh', round_rmsThresh);    
    bSuccess = isempty(find(data.fmts(vowelOnsetIdx : vowelEndIdx, 1) == 0));
    if ~bSuccess
        rmsThresh_min = rmsThresh_min / 2;
%         rmsThresh_step = rmsThresh_step / 2;
    end
end


rmsThresh_old = pdata.(dataFld).rmsThresh(idx_trial);
% pdata.(dataFld).rmsThresh(idx_trial) = rmsThresh;

if ~iscell(uihdls)
    fn = state.trialList.fn{i1};
    
    set(uihdls.edit_rmsThresh, 'String', sprintf('%.8f', rmsThresh));

    info_log(sprintf('Auto-adjusting rmsThresh for trial %s: %.5f -> %.5f\n', ...
                     fn, rmsThresh_old, rmsThresh));
    reproc_cbk([], [], dacacheFN, stateFN, uihdls);
else
    info_log(sprintf('Auto-adjusting rmsThresh for trial %s: %.5f -> %.5f\n', ...
                     rawfn, rmsThresh_old, rmsThresh));
    reproc_cbk([], [], dacacheFN, stateFN, uihdls);
end


return