function lst_srt_nLPCs_cbk(hObject, eventdata, dacacheFN, stateFN, uihdls)
val = get(uihdls.lst_srt_nLPCs, 'Value');
str = get(uihdls.lst_srt_nLPCs, 'String');
sel_nLPC = str2num(str{val});

set(uihdls.edit_nLPC, 'String', sprintf('%d', sel_nLPC));
reproc_cbk(uihdls.bt_reproc, [], dacacheFN, stateFN, uihdls);

return