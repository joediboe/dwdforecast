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
zeile_heute_18uhr=$(awk -v vardatum=$datum_heute 'BEGIN { FS=";" } ($1 ~ vardatum && $2 ~ /18:00/) {print NR}' weather.csv)
zeile_morgen_6uhr=$(awk -v vardatum=$datum_morgen 'BEGIN { FS=";" } ($1 ~ vardatum && $2 ~ /06:00/) {print NR}' weather.csv)
# Schleife 6 Tages-Vorhersagen
#   Eintraege naechster Tag  6:00: Temp_min, Regen, Sonnenstunden
#   Eintraege aktueller Tag 18:00: Temp_max
for zaehler in {0..5}
do
  zeile=$(($zeile_morgen_6uhr+8*$zaehler))
  Temp_min=$(awk -v varzeile=$zeile -v varoffset=$temp_offset 'BEGIN { FS=";" } NR==varzeile {print $6+varoffset}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_min" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tempmin_${zaehler}/state"
  Regen=$(awk -v varzeile=$zeile 'BEGIN { FS=";" } NR==varzeile {print $19}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Regen" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Regen_${zaehler}/state"
  Sonnenstunden=$(awk -v varzeile=$zeile 'BEGIN { FS=";" } NR==varzeile {print $34}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Sonnenstunden" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Sonnenstunden_${zaehler}/state"
  zeile=$(($zeile_heute_18uhr+8*$zaehler))
  Temp_max=$(awk -v varzeile=$zeile -v varoffset=$temp_offset 'BEGIN { FS=";" } NR==varzeile {print $5+varoffset}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_max" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tempmax_${zaehler}/state"
  if [ $zaehler -gt 1 ]; then
    datum=$(awk -v varzeile=$zeile 'BEGIN { FS=";" } NR==varzeile {print $1}' weather.csv)
    datum_formatiert="20"${datum:6:2}"-"${datum:3:2}"-"${datum:0:2}
    wochentag=$(date --date "$datum_formatiert" +%A)
    case $wochentag in
      Monday) tag="Montag"
        ;;
      Tuesday) tag="Dienstag"
        ;;
      Wednesday) tag="Mittwoch"
        ;;
      Thursday) tag="Donnerstag"
        ;;
      Friday) tag="Freitag"
        ;;
      Saturday) tag="Samstag"
        ;;
      Sunday) tag="Sonntag"
        ;;
      *) tag=$wochentag
        ;;
      esac
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$tag" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tag_${zaehler}/state"
  fi
done
