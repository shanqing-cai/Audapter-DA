function [marks, marksDesc] = get_preproc_marks()
marks = {'sOnsetTime', 't1OnsetTime', 'dOnsetTime', 'b1OnsetTime', ...
         'gOnsetTime', 'b2OnsetTime', 't2OnsetTime', 'p1OnsetTime', ...
         'p2OnsetTime'};

marksDesc = {'Onset of [s] in "steady"', 'Onset of [t] in "steady"', ...
             'Onset of [d] in "steady"', 'Onset of [b] in "bat"', ...
             'Onset of [g] in "gave"', 'Onset of [b] in "birth"', ...
             'Onset of [t] in "to"', 'Onset of 1st [p] in "pups"', ...
             'Onset of 2nd [p] in "pups"'};

return