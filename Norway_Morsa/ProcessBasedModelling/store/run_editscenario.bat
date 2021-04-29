set XML=langtjern.xml

editscenario --schemadir=%GOTMDIR%\schemas -e nml . %XML% 

del fabm_input.nml

pause
