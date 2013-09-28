function list_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls, varargin)
% set(uihdls.hlist, 'Enable', 'off');
% set(uihdls.bt_reproc, 'Enable', 'off');
% set(uihdls.bt_auto_rmsThresh, 'Enable', 'off');

i1 = get(uihdls.hlist, 'Value');
load(dacacheFN);    % gives pdata
load(stateFN);      % gives state

%%
% if isfield(state.trialList, 'isOther') && state.trialList.isOther(i1) == 1
%     dataFld = 'otherData';
% elseif state.trialList.isRand(i1) == 1
%     dataFld = 'randData';
% elseif state.trialList.isSust(i1) == 1
%     dataFld = 'sustData';
% end
dataFld = 'mainData';
% fprintf('dataFld = %s\n', dataFld);

idx_trial = state.trialList.allOrderN(i1);
if isnan(pdata.(dataFld).rating(idx_trial)) % New
    load(getRawFN_(state.rawDataDir,state.trialList.fn{i1}));	% gives data
    updateParamsUI(uihdls, data);
else
    updateParamsUI(uihdls, pdata, dataFld, idx_trial);
end

if ~isempty(fsic(varargin, 'focus'))
    pdata1 = updateDataUI(uihdls, pdata, dataFld, idx_trial, state, i1, ...
                          'fromList', 'focus');
else
    pdata1 = updateDataUI(uihdls, pdata, dataFld, idx_trial, state, i1, ...
                          'fromList');
end

state.stats(i1) = 1;

save(stateFN, 'state');
if ~isequal(pdata, pdata1)
    pdata = pdata1;
    save(dacacheFN, 'pdata');
    info_log(sprintf('Saved updated pdata to %s', dacacheFN));
end

rating_cbk(uihdls.pm_rating, [], dacacheFN, stateFN, uihdls);

if ~isfield(uihdls, 'exptType') || isequal(uihdls.exptType, 'behav') || isequal(uihdls.exptType, 'fMRI') || ...
   isequal(uihdls.exptType, 'rand-twarp-fmt') || isequal(uihdls.exptType, 'rand-RHY-fmri')
    ostOkay_cbk(uihdls.pm_ostOkay, [], dacacheFN, stateFN, uihdls);
end

asrOkay_cbk(uihdls.pm_asrOkay, [], dacacheFN, stateFN, uihdls);
comments_cbk(uihdls.edit_comments, [], dacacheFN, stateFN, uihdls);
fluencyBtn_cbk(uihdls.hfig, [], dacacheFN, stateFN, uihdls);

updateTrialList(state, uihdls);
set(uihdls.hlist, 'Enable', 'on');
set(uihdls.bt_reproc, 'Enable', 'on');
% set(uihdls.bt_auto_rmsThresh, 'Enable', 'on');
return
