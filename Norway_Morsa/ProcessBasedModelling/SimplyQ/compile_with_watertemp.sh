#!/bin/bash
g++ -fpic -m64 -std=c++11 -c -O2 simplyQ_with_water_temperature_dll.cpp
g++ -o simplyq_with_watertemp.so -m64 -shared simplyQ_with_water_temperature_dll.o
