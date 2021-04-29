@echo off

g++ -c -m64 -std=c++11 -O2 simplyq_with_water_temperature_dll.cpp -fexceptions -fmax-errors=5
g++ -o simplyq_with_watertemp.dll -static -static-libgcc -static-libstdc++ -s -shared simplyq_with_water_temperature_dll.o -Wl,--subsystem,windows