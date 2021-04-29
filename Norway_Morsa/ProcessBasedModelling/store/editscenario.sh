#!/bin/sh

XML=langtjern.xml

unset GOTMDIR
export GOTMGUIDIR=../gui.py

python ../bin/editscenario.py --schemadir=../gui.py/schemas/scenario --export=nml $XML .

unset GOTMGUIDIR
export GOTMDIR=~/GOTM/lake

echo $GOTMDIR

#rm -f fabm_input.nml

