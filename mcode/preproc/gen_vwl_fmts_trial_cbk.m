function varargout = gen_vwl_fmts_trial_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls, varargin)
%% Ad hoc
sent = 'The steady bat gave birth to pups';

vwls = {'eh', 'iy', 'ae', 'ey', 'er', 'uw', 'ah'};

N_FMTS = 2;

%% CONSTANTS
N_FREQ = 1024;
SPECTRO_WIN_SIZE = 128;
SPECTRO_OVERLAP = 64;

%%
load(stateFN);      % gives state
load(dacacheFN);    % gives pdata

%%
idx = get(uihdls.hlist, 'Value');
idx_trial = state.trialList.allOrderN(idx);
rawfn = getRawFN_(state.rawDataDir, state.trialList.fn{idx});
check_file(rawfn);

dataFld = 'mainData';
if ~isfield(pdata.(dataFld), 'asrTBeg')
    error('Cannot find field asrTBeg in pdata from %s. Run genASRTimeLabels_cbk first', ...
          dacacheFN);
end

if ~isfield(pdata.(dataFld), 'asrPhns')
    error('Cannot find field asrPhns in pdata from %s. Run genASRTimeLabels_cbk first', ...
          dacacheFN);
end

tbegs = pdata.(dataFld).asrTBeg(:, idx_trial);
if length(tbegs) ~= length(pdata.(dataFld).asrPhns)
    error('Unexpected number of phones in tbegs (%d ~= %d)', ...
          length(tbegs), length(pdata.(dataFld).asrPhns));
end

%%
if ~isfield(pdata.(dataFld), 'vwlFmts')% -- Vowel-by-vowel formant trajectories -- %
    pdata.(dataFld).vwlFmts = cell(1, length(pdata.(dataFld).rating));
end

if ~isfield(pdata.(dataFld), 'cntFmts') % -- Continuous formant trajectory -- %
    pdata.(dataFld).cntFmts = cell(1, length(pdata.(dataFld).rating));
end

if hObject == uihdls.hmenu_gen_vwl_fmts_trial
    clear TransShiftMex;
end

if pdata.(dataFld).rating == 0
    fprintf(1, 'Trial %s: rating == 0, skipped it.\n', rawfn);
    return
end

if pdata.(dataFld).bASROkay == 0
    fprintf(1, 'Trial %s: rating == 0, skipped it.\n', rawfn);
    return
end

%--

if hObject == uihdls.hmenu_calc_avg_vwl_spect
    spectrograms = struct;
end

for i1 = 1 : numel(vwls)
    v = vwls{i1};
    
    iv = fsic(pdata.(dataFld).asrPhns, v);
    if length(iv) ~= 1
        error('');
    end
    
    t0 = tbegs(iv);
    t1 = tbegs(iv + 1);
    
    load(rawfn);    % gives data
    
    sr = data.params.sr;
    
    sidx0 = round(t0 * sr);
    sidx1 = round(t1 * sr);
    
    sidx0 = round(sidx0 / data.params.frameLen) * data.params.frameLen + 1;
    sidx1 = round(sidx1 / data.params.frameLen) * data.params.frameLen;
    
%     frameDur = data.params.frameLen / data.params.sr;
%     t_pad = data.params.nDelay * frameDur;
    sidx_pad_0 = sidx0 - data.params.frameLen * data.params.nDelay;
    sidx_pad_0 = max([1, sidx_pad_0]);
    sidx_pad_1 = sidx1 + data.params.frameLen * data.params.nDelay;
    sidx_pad_1 = min([length(data.signalIn), sidx_pad_1]);
%     sidx_pad_1 = min([size(data.fmts, 1), round((t1 + tpad) * sr)]);
    
    vwl_wf = data.signalIn(sidx_pad_0 : sidx_pad_1);
       
    dataOut = reprocData(data, 'sig', vwl_wf, 'rmsThresh', 0.0);
    if i1 == 1
        dataOut = reprocData(data, 'sig', vwl_wf, 'rmsThresh', 0.0);
    end
    
    pad_fmts = dataOut.fmts(:, 1 : N_FMTS);
    pn1 = (sidx0 - sidx_pad_0) / data.params.frameLen;
    pn2 = (sidx_pad_1 - sidx1) / data.params.frameLen;
    fmts = pad_fmts(pn1 + 1 : end - pn2, :);
    
    pdata.(dataFld).vwlFmts{idx_trial}.(v) = fmts;
    
    % --- Generate cntFms: continuous formant trajectory --- %
    if i1 == 1
        pdata.(dataFld).cntFmts{idx_trial} = nan(size(data.fmts, 1), N_FMTS);
    end
    
    pdata.(dataFld).cntFmts{idx_trial}((sidx0 - 1) / data.params.frameLen + 1 : (sidx1 / data.params.frameLen), :) = fmts;
    
    % --- Get spectrogram --- %
    if hObject == uihdls.hmenu_calc_avg_vwl_spect
        [s, f, t] = spectrogram(vwl_wf, SPECTRO_WIN_SIZE, SPECTRO_OVERLAP, N_FREQ, data.params.sr);
        s = 20 * log10(abs(s));

        spectrograms.(v) = s;
%         pdata.(dataFld).vwlSpectrogram{idx_trial}.(v) = s;
    end
end

if ~isfield(pdata.(dataFld), 'vwlSpectrogram');
     pdata.(dataFld).vwlSpectrogram = cell(1, length(pdata.(dataFld).vwlFmts));
     
     f_vwls = fields(pdata.(dataFld).vwlFmts{idx_trial});
     for i1 = 1 : length(pdata.(dataFld).vwlFmts)
         pdata.(dataFld).vwlSpectrogram{i1} = struct;
         
         for i2 = 1 : numel(f_vwls)
             v = f_vwls{i2};
             pdata.(dataFld).vwlSpectrogram{i1}.(v) = [];
         end
     end
end

%%
save(dacacheFN, 'pdata');
fprintf(1, 'Saved results to pdata file: %s\n', dacacheFN);

if hObject == uihdls.hmenu_calc_avg_vwl_spect
    varargout{1} = spectrograms;
end
return
