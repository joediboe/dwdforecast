#!/bin/bash
# Input
station="K2791"
temp_offset=-1.6
#
cd /etc/openhab2/html/dwd/
wget -q -O weather_download.csv http://opendata.dwd.de/weather/local_forecasts/poi/${station}-MOSMIX.csv
if [ -s weather_download.csv ]
then
  mv weather_download.csv weather_comma.csv
fi
sed 's/,/\./g' weather_comma.csv > weather.csv
stunde_aktuell_0=$(date +%H)
stunde_aktuell=${stunde_aktuell_0#0}	# aktuelle Stunde ohne fuehrende 0
stunde_00=$((3*($stunde_aktuell/3)))	# Startzeit aktuelle Wettervorhersage (alle 3 h)
stunde_00_0=$(printf "%02d" $stunde_00)	# Jetzt wieder ne 0 vorne dran bei einstelligen
datum_00=$(date +%d.%m.%y)		# aktuelles Datum
beginnzeile=$(awk -v vardat=$datum_00 -v varh=${stunde_00_0}:00 'BEGIN { FS=";" } $1 ~ vardat && $2 ~ varh {print NR}' weather.csv)
# Schleife 7 3-Stunden-Vorhersagen: Temp, Regen, Wolken-Achtel
for zaehler in {0..7}
do
  zeile=$(($beginnzeile+$zaehler))
#echo $zeile
  Stunde_Beginn=$(((3*$zaehler+$stunde_00)%24))
  Stunde_Ende=$(((3*$zaehler+$stunde_00+3)%24))
  Stunde_Beginn_0=$(printf "%02d" $Stunde_Beginn)
  Stunde_Ende_0=$(printf "%02d" $Stunde_Ende)
  Zeit_String="$Stunde_Beginn - $Stunde_Ende"
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Zeit_String" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Zeit_${zaehler}/state"
  Temp=$(awk -v varzaehler=$zeile -v varoffset=$temp_offset 'BEGIN { FS=";" } NR==varzaehler {print $3+varoffset}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Temp_${zaehler}/state"
  Regen=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $16}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Regen" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Regen_${zaehler}/state"
  Wolken=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $28}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Wolken" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Wolken_${zaehler}/state"
done
# Tagesvorhersage
datum_heute=$(date +%d.%m.%y)
datum_morgen=$(date -d "+1 days" +%d.%m.%y)
