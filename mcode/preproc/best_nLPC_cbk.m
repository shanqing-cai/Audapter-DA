function best_nLPC_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
load(dacacheFN); % Gives pdata

flds = {'otherData', 'randData', 'sustData'};
bFoundMissing = 0;
a_nLPC_lst = [];
for h1 = 1 : numel(flds)
    fld = flds{h1};
    
    if length(pdata.(fld).rawDataFNs) == 0
        continue;
    end
    
    if ~isfield(pdata.(fld), 'srt_nLPCs')
        bFoundMissing = 1;
        break;
    end

    for h2 = 1 : numel(pdata.(fld).srt_nLPCs)
        if pdata.(fld).bDiscard(h2)
            continue;
        end

        if pdata.(fld).rating(h2) == 0
            continue;
        end

        if isempty(pdata.(fld).srt_nLPCs{h2})
            bFoundMissing = 1;
            break;
        else
            a_nLPC_lst = [a_nLPC_lst; pdata.(fld).srt_nLPCs{h2}];
        end
    end            
end

if bFoundMissing
    fprintf(2, 'ERROR: Overall best nLPC cannot be determined until auto nLPC has not been run on all trials.\n');
    return
end

fprintf('\n');
a_nLPCs = unique(a_nLPC_lst(:, 1));
a_nLPCs = sort(a_nLPCs);
for i1 = 1 : numel(a_nLPCs)
    fprintf('nLPC = %d:\tbest in %d of %d trials.\n', ...
            a_nLPCs(i1),  length(find(a_nLPC_lst(:, 1) == a_nLPCs(i1))), ...
            length(a_nLPC_lst(:, 1)));
end

fprintf('======================================\n');
fprintf('Overall best nLPC = %d\n\n', mode(a_nLPC_lst(:, 1)))

if hObject == uihdls.hmenu_nLPC_set_overall_best
    if ~isfield(pdata, 'nLPC_status')
        pdata.nLPC_status = 'user';
    else
        if isequal(pdata.nLPC_status, 'overall_best');
            fprintf(1, 'WARNING: Data are already set to overall best nLPC. No changes will be made.\n');
            return;
        end
    end
    
    fields = {'randData', 'sustData'};
    for i1 = 1 : numel(fields)
        fld = fields{i1};

        if isequal(pdata.nLPC_status, 'user')
            pdata.(fld).user_nLPCs = pdata.(fld).nLPC; % Backup user selections
        end

        for i2 = 1 : numel(pdata.(fld).nLPC)
            if isempty(pdata.(fld).srt_nLPCs{i2})
                continue;
            end
            
            if ~isnan(pdata.(fld).nLPC) 
                pdata.(fld).nLPC(i2) = mode(a_nLPC_lst(:, 1));
            end
        end
    end    
    
    pdata.nLPC_status = 'overall_best';
    save(dacacheFN, 'pdata');
    fprintf(1, 'Set all nLPCs to overall best (%d). \npdata saved to %s\n', ...
            mode(a_nLPC_lst(:, 1)), dacacheFN);
        
    set(uihdls.hlist, 'Enable', 'off');
    lst_str = get(uihdls.hlist, 'String');
    for i1 = 1 : numel(lst_str)
        set(uihdls.hlist, 'Value', i1);
        list_cbk(uihdls.hlist, [], dacacheFN, stateFN, uihdls);
        set(uihdls.hlist, 'Enable', 'off');
        drawnow;
    end
    set(uihdls.hlist, 'Enable', 'on');
    
    fprintf(1, 'Set all nLPCs to overall best (%d). \npdata saved to %s\n', ...
            mode(a_nLPC_lst(:, 1)), dacacheFN);
    
end


return