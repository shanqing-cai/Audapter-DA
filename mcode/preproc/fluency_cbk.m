function fluency_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
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

str = get(uihdls.edit_fluency, 'String');

bChanged = 0;
if ~isfield(pdata.(dataFld), 'fluency_comments')
    pdata.(dataFld).fluency_comments = cell(size(pdata.(dataFld).rawDataFNs));
    bChanged = 1;
end

if ~isequal(pdata.(dataFld).fluency_comments{idx_trial}, str)
    pdata.(dataFld).fluency_comments{idx_trial} = str;
    bChanged = 1;
end

if bChanged
    save(dacacheFN, 'pdata');

    fn = state.trialList.fn{i1};
    fprintf('INFO: %s: trial: %s: fluency_comments -> [%s]\n', ...
            mfilename, fn, pdata.(dataFld).fluency_comments{idx_trial});
end
return