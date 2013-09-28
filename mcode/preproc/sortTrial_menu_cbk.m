function sortTrial_menu_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
daSettings = data_analysis_settings(uihdls.exptType);

%% --- Determine the level and item number at which the selection occurred --- %%
lv = NaN;
isel = NaN;
for i1 = 1 : size(uihdls.hmenu_sortTrials_opts, 1)
    if ~isempty(find(uihdls.hmenu_sortTrials_opts(i1, :) == hObject));
        lv = i1;
        isel = find(uihdls.hmenu_sortTrials_opts(i1, :) == hObject);
        break;
    end
end
        
if isnan(lv) || isnan(isel)
    error_log('Cannot determine the level at which the menu click occurred');
end

%% --- Determine the current selection status in all levels --- %%
currSels = nan(1, daSettings.SORT_TRIAL_LEVELS);
for i1 = 1 : size(uihdls.hmenu_sortTrials_opts, 1)
    for i2 = 1 : size(uihdls.hmenu_sortTrials_opts, 2)
        if isequal(get(uihdls.hmenu_sortTrials_opts(i1, i2), 'checked'), 'on')
            currSels(i1) = i2;
            break;
        end
    end
end

if ~isempty(find(isnan(currSels)))
    error_log('Cannot determine the current selection status in trial sorting menu');
end

%% --- Check for conflict --- %%
for i1 = 1 : daSettings.SORT_TRIAL_LEVELS
    if i1 == lv
        continue;
    end
    
    if currSels(i1) == isel
        selItemName = daSettings.ALL_SORT_MODES_DESC{isel};
        info_log(sprintf('Conflict detected: Item "%s" is already selected at sorting level %d.', selItemName, isel), '-warn');
        info_log('Therefore the trial list will not be updated', '-warn');
        return
    end
end

%% --- Get new sorting paradigm and update trial list  --- %%
srtMode = daSettings.ALL_SORT_MODES(currSels);
srtMode(lv) = daSettings.ALL_SORT_MODES(isel);

load(stateFN); % gives state
trialList = sort_trial_list(state.trialList, srtMode);

reOrder = nan(1, length(trialList.allOrderN));
for i1 = 1 : numel(reOrder)
    reOrder(i1) = find(state.trialList.allOrderN == trialList.allOrderN(i1), 1);
end
assert(isequal(trialList.allOrderN, state.trialList.allOrderN(reOrder)));

state.trialList = trialList;
state.stats = state.stats(reOrder);

save(stateFN, 'state');

%% Update check marks
set(uihdls.hmenu_sortTrials_opts(lv, currSels(lv)), 'checked', 'off');
set(uihdls.hmenu_sortTrials_opts(lv, isel(lv)), 'checked', 'on');

updateTrialList(state, uihdls);

info_log(sprintf('Trial list order updated'));
return