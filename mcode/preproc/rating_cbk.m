function rating_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
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

val = get(uihdls.pm_rating, 'Value');
items = get(uihdls.pm_rating, 'String');

rating_old = pdata.(dataFld).rating(idx_trial);

pdata.(dataFld).rating(idx_trial) = str2num(items{val});



bChanged = ~isequal(rating_old, pdata.(dataFld).rating(idx_trial));

if bChanged
    save(dacacheFN, 'pdata');
    fprintf('Saved to %s\n', dacacheFN);
    
    fn = state.trialList.fn{i1};
    fprintf('INFO: trial: %s: rating -> %d\n', fn, pdata.(dataFld).rating(idx_trial));
end
return