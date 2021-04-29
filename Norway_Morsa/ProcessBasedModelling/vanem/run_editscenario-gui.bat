set XML=langtjern.xml

editscenario --schemadir=%GOTMDIR%\schemas -e nml . -g %XML% 

del fabm_input.nml

pause
