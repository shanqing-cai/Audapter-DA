function updateTrialList(state, uihdls, varargin)
%% CONSTANTS
bIsRHY = ~isfield(uihdls, 'exptType') || isequal(uihdls.exptType, 'behav') || isequal(uihdls.exptType, 'fMRI') || ...
         isequal(uihdls.exptType, 'rand-twarp-fmt') || isequal(uihdls.exptType, 'rand-RHY-fmri');

if bIsRHY
    ALL_PERT_TYPES = {'noPert', 'F1Up', 'decel'};
    ALL_MASK_TYPES = {'noMask'};
elseif isequal(uihdls.exptType, 'sust-fmt') 
    ALL_PERT_TYPES = {'noPert', 'pert'};
    ALL_MASK_TYPES = {'noMask', 'mask'};
else
    error_log(sprintf('%s: encountered unsupported exptType: %s', ...
                      mfilename, uihdls.exptType));
end

%%
listItems = cell(1, numel(state.trialList.fn));
nFirstUnproc = Inf;

revButStr = get(uihdls.hreveal, 'String');
if isequal(revButStr, 'Reveal trial details')
    bReveal = 0;
else
    bReveal = 1;
end

showCommentsStr = get(uihdls.hShowComments, 'String');
bShowComments = isequal(showCommentsStr, 'Hide comments');

if bShowComments
    load(uihdls.dacacheFN); % gives pdata
end

for i1 = 1 : numel(state.trialList.fn)
    t_phase = state.trialList.phase{i1};
    t_block = state.trialList.block(i1);
    t_trialN = state.trialList.trialN(i1);
    t_word = state.trialList.word{i1};
    
    t_pertType = ALL_PERT_TYPES{state.trialList.pertType(i1) + 1};
    if isequal(t_pertType, 'noPert')
        t_pertType = '';
    end
    
    if isfield(state.trialList, 'noiseMasked')
        t_maskType = ALL_MASK_TYPES{state.trialList.noiseMasked(i1) + 1};
    else
        t_maskType = 'noMask';
    end
    if isequal(t_maskType, 'noMask')
        t_maskType = '';
    end
    
    
    strDet = sprintf('{%s,%s} %s, block %d, trial %d (%s)', ...
                     t_pertType, t_maskType, t_phase, t_block, t_trialN, t_word);
    
    if state.stats(i1) == 0
        if bReveal == 0
            listItems{i1} = sprintf('(_) Trial #%d', i1);
        else            
            listItems{i1} = sprintf('(_) Trial #%d - %s', i1, strDet);
        end
        if i1 < nFirstUnproc
            nFirstUnproc = i1;
        end
    else
        if bReveal == 0
            listItems{i1} = sprintf('(*) Trial #%d', i1);
        else            
            listItems{i1} = sprintf('(*) Trial #%d - %s', i1, strDet);
        end
        
        % Load comments
        if bShowComments
            t_phase = state.trialList.phase{i1};
            t_orderN = state.trialList.allOrderN(i1);
            if isequal(t_phase, 'other')
                pfld = 'otherData';
            elseif isequal(t_phase, 'rand')
                pfld = 'randData';
            else
                pfld = 'sustData';
            end
                                   
            t_comment = pdata.(pfld).comments{t_orderN};
            if isempty(t_comment)
                t_comment = '';
            end
         
            listItems{i1} = sprintf('%s {%s}', listItems{i1}, t_comment);
        end
    end
end

set(uihdls.hlist, 'String', listItems);

if ~isempty(fsic(varargin, 'next'))
    if nFirstUnproc == Inf        
%         msgbox('Preproc has complete on all trials. No more trials to preproc.', 'Preproc completed', 'modal');
%         return

        currLoc = get(uihdls.hlist, 'Value');
        if currLoc == length(get(uihdls.hlist, 'String'));
            set(uihdls.hlist, 'Value', 1);
        else
            set(uihdls.hlist, 'Value', currLoc + 1);
        end
        
%         idxa = fsic(varargin, 'next');
%         dacacheFN = varargin{idxa + 1};
%         stateFN = varargin{idxa + 2};
%         list_cbk([], [], dacacheFN, stateFN, uihdls);
%         return
    else
        set(uihdls.hlist, 'Value', nFirstUnproc);
    end
    
    idxa = fsic(varargin, 'next');    
    dacacheFN = varargin{idxa + 1};
    stateFN = varargin{idxa + 2};    
    list_cbk([], [], dacacheFN, stateFN, uihdls);
elseif nargin == 5 % Set to specific trial
    s_phase = varargin{1};
    s_repNum = varargin{2};
    s_trialNum = varargin{3};
    
    bFoundTrial = 0;   
    for i1 = 1 : numel(state.trialList.phase)
        if isequal(state.trialList.phase{i1}, s_phase) && ...
           isequal(state.trialList.block(i1), s_repNum) && ...
           isequal(state.trialList.trialN(i1), s_trialNum)
            bFoundTrial = 1;
            break;
        end
    end
    
    if bFoundTrial == 0
        error('Failed to find trial: phase %s, rep #%d, trial #%d', ...
              s_phase, s_repNum, s_trialNum);
    else
        set(uihdls.hlist, 'Value', i1);
    end
end
return