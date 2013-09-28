function gen_vwl_fmts_all_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
%% Constants
SPECT_NORMT_N = 100;

%%
load(dacacheFN);    % gives pdata
load(stateFN);      % gives state

%% Check whether ASR is complete
bFoundMissing = 0;
flds = {'mainData'};

for h1 = 1 : numel(flds)
    fld = flds{h1};
    
    if ~isfield(pdata.(fld), 'asrTBeg')
        bFoundMissing = 1;
        break;
    end

    for h2 = 1 : numel(pdata.(fld).rating)                
        if pdata.(fld).rating(h2) == 0
            continue;
        end

%                 if isnan(pdata.(fld).sOnsetTime(h2)) || ...
%                         isnan(pdata.(fld).p2OnsetTime(h2))
        if isnan(pdata.(fld).rating(h2)) || ...
           isnan(pdata.(fld).bASROkay(h2))
            bFoundMissing = 1;
            break;
        end
        
        if pdata.(fld).bASROkay(h2) == 1 && ~isempty(find(isnan(pdata.(fld).asrTBeg(:, h2))))
            bFoundMissing = 1;
            break;
        end
    end            
end

if bFoundMissing
    msgbox('gen_vwl_fmts_all_cbk all cannot proceed at this time because rating and/or ASR are not finished yet', ...
           'gen_vwl_fmts_all_cbk proceed', 'error');
    return
end

%%
dataFld = 'mainData';

clear TransShiftMex;
i1s = get(uihdls.hlist, 'String'); % Individual trial

if hObject == uihdls.hmenu_gen_vwl_fmts_all
    for n = 1 : length(i1s)
        set(uihdls.hlist, 'Value', n);
        drawnow;

        idx_trial = state.trialList.allOrderN(n);

        if pdata.(dataFld).rating(idx_trial) == 0 || pdata.(dataFld).bDiscard(idx_trial) == 1
            fprintf(1, 'INFO: Trial #%d in the list has a rating of 0 and/or a bDiscard of 1. gen_vwl_fmts will not be extracted for this trial.\n', n);
            continue
        end

        if pdata.(dataFld).bASROkay(idx_trial) == 0
            fprintf(1, 'INFO: Trial #%d in the list has a bASROkay ==  0. gen_vwl_fmts will not be extracted for this trial.\n', n);
            continue;
        end

        gen_vwl_fmts_trial_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls);
    end
elseif hObject == uihdls.hmenu_calc_avg_vwl_spect
    a_spect = struct;
    a_spect_pt = [];
    a_spect_br = [];
    
    for n = 1 : length(i1s)    
        set(uihdls.hlist, 'Value', n);
        drawnow;

        idx_trial = state.trialList.allOrderN(n);

        if pdata.(dataFld).rating(idx_trial) == 0 || pdata.(dataFld).bDiscard(idx_trial) == 1
            fprintf(1, 'INFO: Trial #%d in the list has a rating of 0 and/or a bDiscard of 1. gen_vwl_fmts will not be extracted for this trial.\n', n);
            continue
        end

        if pdata.(dataFld).bASROkay(idx_trial) == 0
            fprintf(1, 'INFO: Trial #%d in the list has a bASROkay ==  0. gen_vwl_fmts will not be extracted for this trial.\n', n);
            continue;
        end

        t_spectrograms = gen_vwl_fmts_trial_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls);
        
        flds = fields(t_spectrograms);
        
        for i1 = 1 : numel(flds)
            fld = flds{i1};
            if ~isfield(a_spect, fld)
                a_spect.(fld) = {};
            end
            
            a_spect.(fld){end + 1} = t_spectrograms.(fld);
            
        end
        a_spect_pt(end + 1) = pdata.(dataFld).pertType(idx_trial);
        a_spect_br(end + 1) = pdata.(dataFld).bRhythm(idx_trial);
    end
    
    %--- Calcualte averages of the spectrograms ---%
    avg_spect_realt = struct;
    avg_spect_normt = struct;
    
    a_spect_realt = struct;
    a_spect_normt = struct;
    
    nrh = max(pdata.(dataFld).bRhythm) + 1;
    npt = max(pdata.(dataFld).pertType) + 1;
    
    flds = fields(a_spect);
    for i1 = 1 : numel(flds)
        fld = flds{i1};
        
        nfr = size(a_spect.(fld){1}, 1);
        
%         assert(length(pdata.(dataFld).pertType) == length(a_spect.(fld)));
        avg_spect_realt.(fld) = cell(nrh, npt);
        avg_spect_normt.(fld) = cell(nrh, npt);
        
        a_lens = nan(1, length(a_spect.(fld)));
        for i2 = 1 : length(a_spect.(fld))
            a_lens(i2) = size(a_spect.(fld){i2}, 2);
        end
        
        max_len = max(a_lens);
                
        for i2 = 1 : npt
            for i3 = 1 : nrh
                avg_spect_realt.(fld){i3, i2} = nan(nfr, max_len);
                a_spect_realt.(fld){i3, i2} = nan(nfr, max_len, 0);
    
                avg_spect_normt.(fld){i3, i2} = nan(nfr, SPECT_NORMT_N);
                a_spect_normt.(fld){i3, i2} = nan(nfr, SPECT_NORMT_N, 0);
            end
        end
        
        assert(length(a_spect_pt) == length(a_spect.(fld)));             
        for i2 = 1 : length(a_spect.(fld))
            padded_s = [a_spect.(fld){i2}, nan(nfr, max_len - size(a_spect.(fld){i2}, 2))];
            
            rn = a_spect_br(i2);
            pt = a_spect_pt(i2);
            
            a_spect_realt.(fld){rn + 1, pt + 1}(:, :, end + 1) = padded_s;
            
            tx = 1 : size(a_spect.(fld){i2}, 2);
            txi = linspace(1, size(a_spect.(fld){i2}, 2), SPECT_NORMT_N);
            
%             a_spect_normt.(fld){pt + 1}(:, :, end + 1) = nan(nfr, SPECT_NORMT_N);
%             for i3 = 1 : nfr
            a_spect_normt.(fld){rn + 1, pt + 1}(:, :, end + 1) = interp1(tx, a_spect.(fld){i2}', txi)';
%             end
        end
        
        %--- Get arithmetic mean ---%
        for i2 = 1 : npt
            for i3 = 1 : nrh
                avg_spect_realt.(fld){i3, i2} = nanmean(a_spect_realt.(fld){i3, i2}, 3);
                avg_spect_normt.(fld){i3, i2} = nanmean(a_spect_normt.(fld){i3, i2}, 3);
            end
        end
        
        a_spect_realt = rmfield(a_spect_realt, fld); % For saving memory
        a_spect_normt = rmfield(a_spect_normt, fld); % For saving memory
    end
    
    pdata.(dataFld).avg_spect_realt = avg_spect_realt;
    pdata.(dataFld).avg_spect_normt = avg_spect_normt;
    save(dacacheFN, 'pdata');
    fprintf(1, 'INFO: DONE: Appended avg_spect_realt and avg_spect_normt to pdata.%s at %s\n', dataFld, dacacheFN);
end

return