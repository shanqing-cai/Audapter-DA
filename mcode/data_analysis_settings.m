function settings = data_analysis_settings(exptType)
settings.ALL_SORT_MODES = {'trialOrder', 'stimUtter', 'pertType', 'noiseMasked', 'bRhythm'};
settings.ALL_SORT_MODES_DESC = {'Trial number', 'Stimulus utterance', 'Perturbation type', ...
                                'Noise masking', 'Rhythm condition'};
settings.SORT_TRIAL_LEVELS = 2;
% settings.DEFAULT_SORT_MODE ={'behav', {'bRhythm', 'stimUtter'};      % Legacy
%                              'fMRI',  {'bRhythm', 'stimUtter'};       % Legacy
%                              'sust-fmt', {'noiseMasked', 'stimUtter'}};

if isequal(exptType, 'sust-fmt')
    settings.DA_CACHE_DIR = 'C:\Users\UCUSER\dacache';

    settings.POST_EXPT_RMS_THRESH = 0.0;
    settings.POST_EXPT_RMS_RATIO_THRESH = 0.0;
    settings.PHN_ALIGN_CLR = [0.5, 0.5, 1];
    settings.DEFAULT_SORT_MODE = {'noiseMasked', 'stimUtter'};
    
else
    error_log(sprintf('Cannot find settings for exptType: %s', exptType));
end

return