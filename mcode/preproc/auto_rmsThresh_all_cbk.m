function auto_rmsThresh_all_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls, varargin)
% Check whether the preproc has finished.
load(stateFN); % gives state
if ~isempty(find(state.stats == 0))
    msgbox('There are some unprocessed trials. Please finish processing all trials before using Auto all', 'Unable to execute Auto ALL');
    return
end

if isempty(fsic(varargin, 'noConfirm'))
    answer = questdlg('Are you sure you want to run auto RMS on all trials of this subject?', 'Confirm Auto RMS all...');
else
    answer = 'Yes';
end

if isequal(answer, 'Yes')
    t_str = get(uihdls.hlist, 'String');    
    for i1 = 1 : numel(t_str)
        set(uihdls.hlist, 'enable', 'off');
        set(uihdls.hlist, 'Value', i1);
        list_cbk([], [], dacacheFN, stateFN, uihdls)
        drawnow;
        
        auto_rmsThresh_cbk([], [], dacacheFN, stateFN, uihdls);
    end
    set(uihdls.hlist, 'enable', 'on');
end
return