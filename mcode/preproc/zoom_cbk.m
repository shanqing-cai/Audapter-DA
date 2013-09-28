function zoom_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
zdat = guidata(uihdls.haxes1);

xlim = [NaN, NaN];
if hObject == uihdls.hzo % Zoom out
    xlim(1) = zdat.currXLim(1) - (zdat.currXLim(1) - zdat.tmin) * 0.1;
    xlim(2) = zdat.currXLim(2) + (zdat.tmax - zdat.currXLim(2)) * 0.1;
elseif hObject == uihdls.hzi % Zoom in
    xlim(1) = zdat.currXLim(1) + 0.1 * range(zdat.currXLim);
    xlim(2) = zdat.currXLim(2) - 0.1 * range(zdat.currXLim);
elseif hObject == uihdls.hpleft % Pan left
    xlim(1) = zdat.currXLim(1) - 0.1 * range(zdat.currXLim);    
    if xlim(1) < zdat.tmin
        xlim(1) = zdat.tmin;
    end
    xlim(2) = xlim(1) + range(zdat.currXLim);
elseif hObject == uihdls.hpright
    xlim(2) = zdat.currXLim(2) + 0.1 * range(zdat.currXLim);    
    if xlim(2) > zdat.tmax
        xlim(2) = zdat.tmax;
    end
    xlim(1) = xlim(2) - range(zdat.currXLim);
else % Default zoom
    xlim = zdat.defXLim;    
end

zdat.currXLim = xlim;
guidata(uihdls.haxes1, zdat);

set(gcf, 'CurrentAxes', uihdls.haxes2);
set(gca, 'XLim', xlim);

set(gcf, 'CurrentAxes', uihdls.haxes1);
set(gca, 'XLim', xlim);

return