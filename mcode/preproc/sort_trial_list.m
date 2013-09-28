function lst = sort_trial_list(lst0, ord)
if ~iscell(ord)
    ord = {ord};
end

%% Get unique field values, as preparation for sorting
n = length(lst0.fn);

ocd = nan(n, length(ord));

uniq = {};
for i1 = 1 : numel(ord)
    if isequal(ord{i1}, 'trialOrder')
        uniq{i1} = lst0.trialOrder;
    elseif isequal(ord{i1}, 'stimUtter')
        uniq{i1} = sort(unique(lst0.word));
    elseif isequal(ord{i1}, 'pertType') || isequal(ord{i1}, 'noiseMasked') || isequal(ord{i1}, 'bRhythm')
        uniq{i1} = sort(unique(lst0.(ord{i1})));   
    end
end

%% Code all trials 
for i1 = 1 : n
    for i2 = 1 : numel(ord)
        if isequal(ord{i2}, 'trialOrder') || isequal(ord{i2}, 'pertType') || isequal(ord{i2}, 'noiseMasked') || isequal(ord{i2}, 'bRhythm')
            val = lst0.(ord{i2})(i1);
        elseif isequal(ord{i2}, 'stimUtter')
            val = lst0.word{i1};
        end
        
        if iscell(uniq{i2})
            ocd(i1, i2) = fsic(uniq{i2}, val);
        else
            ocd(i1, i2) = find(uniq{i2} == val, 1);
        end
    end
end

%% Perform sorting
for i1 = length(ord) : - 1 : 2
    maxval = max(ocd(:, i1));
    mult = 10 ^ ceil(log10(maxval + 1));
    
    ocd(:, 1 : i1 - 1) = mult * ocd(:, 1 : i1 - 1);
end
ocds = sum(ocd, 2);

[ocds, idxSrt] = sort(ocds);

%% Randomize within trials of the same order code
ordn = nan(n, 1);
cnt = 1;

while ~isempty(ocds)
    idxa = find(ocds == ocds(1));
    k = idxa(end);
    
    tn = idxSrt(idxa);
    tn = tn(randperm(length(tn)));
    
    ordn(cnt : cnt + length(tn) - 1) = tn;
    
    cnt = cnt + k;
    
    ocds = ocds(k + 1 : end);
    idxSrt = idxSrt(k + 1 : end);
end

assert(isempty(find(isnan(ordn))));

%% Create new, sorted trial list
lst = struct;
flds = fields(lst0);
for i1 = 1 : numel(flds)
    fld = flds{i1};
    
    lst.(fld) = lst0.(fld)(ordn);
end
return