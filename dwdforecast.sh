#!/bin/bash
wget -O weather.csv http://opendata.dwd.de/weather/local_forecasts/poi/K2791-MOSMIX.csv
stunde_aktuell=$(date +%H)
stunde_aktuell=${stunde_aktuell#0}
echo $stunde_aktuell
stunde_00=$((3*($stunde_aktuell/3)))
echo $stunde_00
foo=$(printf "%02d" $stunde_00)
echo $foo
echo "test"
