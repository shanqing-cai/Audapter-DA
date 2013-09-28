function ostOkay_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
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

idx_trial = state.trialList.allOrderN(i1);

val = get(uihdls.pm_ostOkay, 'Value');
items = get(uihdls.pm_ostOkay, 'String');

bChanged = 0;

if pdata.(dataFld).bOSTOkay(idx_trial) ~= isequal(items{val}, 'Good')
    pdata.(dataFld).bOSTOkay(idx_trial) = isequal(items{val}, 'Good');
    bChanged = 1;
end

if bChanged
    save(dacacheFN, 'pdata');
    fprintf('Saved to %s\n', dacacheFN);

    fn = state.trialList.fn{i1};
    fprintf('INFO: trial: %s: bOSTOkay -> %d\n', fn, pdata.(dataFld).bOSTOkay(idx_trial));
end
return