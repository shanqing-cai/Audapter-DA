function playSig_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls, mode)
bIsRHY = ~isfield(uihdls, 'exptType') || isequal(uihdls.exptType, 'behav') || isequal(uihdls.exptType, 'fMRI') || ...
         isequal(uihdls.exptType, 'rand-twarp-fmt') || isequal(uihdls.exptType, 'rand-RHY-fmri');

tridx = get(uihdls.hlist, 'Value');

% load(dacacheFN);    % gives pdata
load(stateFN);      % gives state

hostName=deblank(getHostName);
if bIsRHY
    if isequal(hostName,'smcg-w510') || isequal(hostName,'smcgw510') || isequal(hostName,'smcg_w510')
        driveLet = 'G:';
    else
        error('Unsupported host: %s', hostName);
    end
    
    rfn = getRawFN_(state.rawDataDir,state.trialList.fn{tridx});
    if ~isequal(rfn(1 : 2), driveLet)
        rfn(1 : 2) = driveLet;
    end
else
    rfn = state.trialList.fn{tridx};
end

if ~isfile(rfn)
    error_log(sprintf('%s: Failed to find raw data file: %s', mfiename, rfn));
end
load(rfn); % gives data

if isequal(mode, 'in')
    soundsc(data.signalIn, data.params.sr);
elseif isequal(mode, 'out')
    soundsc(data.signalOut, data.params.sr);
elseif isequal(mode, 'in/out')
    try
        set(uihdls.hfig_aux, 'Visible', 'on');
    catch err
        uihdls.hfig_aux = gen_comp_fig;
    end
            
    set(0, 'CurrentFigure', uihdls.hfig_aux);
    
    clf;
    subplot('Position', [0.1, 0.5, 0.8, 0.4]);
    show_spectrogram(data.signalIn, data.params.sr, 'noFig');
    set(gca, 'YTick', [0 : 500 : 4000]);
    grid on;
    
    ylabel('Frequency (Hz)');
    xlabel('Time (s)');
    
    subplot('Position', [0.1, 0.1, 0.8, 0.4]);
    show_spectrogram(data.signalOut, data.params.sr, 'noFig');
    set(gca, 'YTick', [0 : 500 : 4000]);
    grid on;
    
    ylabel('Frequency (Hz)');
    xlabel('Time (s)');
    drawnow;
    
%     soundsc(data.signalIn, data.params.sr);
%     soundsc(data.signalOut, data.params.sr); 
end

return
