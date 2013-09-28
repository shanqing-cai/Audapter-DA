function relabel_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
i1 = get(uihdls.hlist, 'Value');
load(dacacheFN);    % gives pdata
load(stateFN);      % gives state

% if isfield(state.trialList, 'isOther') && state.trialList.isOther(i1) == 1
%     dataFld = 'otherData';
% elseif state.trialList.isRand(i1) == 1
%     dataFld = 'randData';
% elseif state.trialList.isSust(i1) == 1
%     dataFld = 'sustData';
% end
dataFld = 'mainData';
[marks, marksDesc] = get_preproc_marks();

idx_trial = state.trialList.allOrderN(i1);

% pdata.(dataFld).vowelOnsetIdx(idx_trial) = NaN;
% pdata.(dataFld).vowelEndIdx(idx_trial) = NaN;
% pdata.(dataFld).vowelOnset(idx_trial) = NaN;
% pdata.(dataFld).vowelEnd(idx_trial) = NaN;
for n = 1 : numel(marks)
    pdata.(dataFld).(marks{n})(idx_trial) = NaN;
end

save(dacacheFN, 'pdata');

if isequal(uihdls.bt_relabel_focus, hObject) % Focus and relabel
    list_cbk([], [], dacacheFN, stateFN, uihdls, 'focus');
else
    list_cbk([], [], dacacheFN, stateFN, uihdls);
end
return