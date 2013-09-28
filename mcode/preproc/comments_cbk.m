function comments_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
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

str = get(uihdls.edit_comments, 'String');

comments_old = pdata.(dataFld).comments{idx_trial};

pdata.(dataFld).comments{idx_trial} = str;

bChanged = ~isequal(comments_old, pdata.(dataFld).comments{idx_trial});

if bChanged
    save(dacacheFN, 'pdata');
    fprintf('Saved to %s\n', dacacheFN);

    fn = state.trialList.fn{i1};
    fprintf('INFO: trial: %s: comments -> [%s]\n', fn, pdata.(dataFld).comments{idx_trial});
end
return