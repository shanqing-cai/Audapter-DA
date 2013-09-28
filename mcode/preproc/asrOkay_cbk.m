function asrOkay_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
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

val = get(uihdls.pm_asrOkay, 'Value');
items = get(uihdls.pm_asrOkay, 'String');

bChanged = 0;
if pdata.(dataFld).bASROkay(idx_trial) ~= isequal(items{val}, 'Good')
    pdata.(dataFld).bASROkay(idx_trial) = isequal(items{val}, 'Good');
    bChanged = 1;
end

if bChanged
    save(dacacheFN, 'pdata');
    fprintf('Saved to %s\n', dacacheFN);

    fn = state.trialList.fn{i1};
    fprintf('INFO: trial: %s: bASROkay -> %d\n', fn, pdata.(dataFld).bASROkay(idx_trial));
end
return