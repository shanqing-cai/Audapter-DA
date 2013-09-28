function fluencyBtn_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
%% Consants
clrG = [0, 1, 0];
clrR = [1, 0, 0];
%%

i1 = get(uihdls.hlist, 'Value');
load(dacacheFN);    % gives pdata
load(stateFN);      % gives state

dataFld = 'mainData';

idx_trial = state.trialList.allOrderN(i1);

utterWords = splitstring(pdata.(dataFld).words{idx_trial});
fluencyCode_old = pdata.(dataFld).fluencyCode{idx_trial};

for i1 = 1 : numel(utterWords)
    if hObject == uihdls.btnFluencyWords(i1)
        if isequal(get(uihdls.btnFluencyWords(i1), 'ForegroundColor'), clrG);
            set(uihdls.btnFluencyWords(i1), 'ForegroundColor', clrR);
        else
            set(uihdls.btnFluencyWords(i1), 'ForegroundColor', clrG);
        end
    end
end

% --- Get fluency code --- %
t_fluencyCode = [];
for i1 = 1 : numel(utterWords)
    if isequal(get(uihdls.btnFluencyWords(i1), 'ForegroundColor'), clrR)
        t_fluencyCode(end + 1) = i1;
    end
end

str = get(uihdls.edit_comments, 'String');

if ~isequal(fluencyCode_old, t_fluencyCode)
    pdata.(dataFld).fluencyCode{idx_trial} = t_fluencyCode;
    save(dacacheFN, 'pdata');
    
    fn = state.trialList.fn{i1};
    fprintf(1, 'INFO: trial: %s: fluencyCode = \n\t[', fn);
    
    for i1 = 1 : numel(pdata.(dataFld).fluencyCode{idx_trial})
        fprintf('%d ', pdata.(dataFld).fluencyCode{idx_trial}(i1))
    end
    
    fprintf(1, ']\n');
    
    fprintf(1, 'INFO: %s: saved pdata at %s\n', mfilename, dacacheFN); 
end
    

return