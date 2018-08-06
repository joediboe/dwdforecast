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
# Schleife 7 3-Stunden-Vorhersagen: Temp, Regen, Regenwahrscheinlichkeit, Wolken-Achtel
Temp_max=-100
Temp_min=100
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
  if (( $(echo "$Temp > $Temp_max" | bc -l) )); then
    Temp_max=$Temp
  fi
  if (( $(echo "$Temp < $Temp_min" | bc -l) )); then
    Temp_min=$Temp
  fi
  Regen=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $16}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Regen" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Regen_${zaehler}/state"
  Regenwahrscheinlichkeit=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $20}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Regenwahrscheinlichkeit" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Regenwahrscheinlichkeit_${zaehler}/state"
  Wind=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $10}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Wind" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Wind_${zaehler}/state"
  maxWind=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $11}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$maxWind" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_maxWind_${zaehler}/state"
  Taupunkt=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $4}' weather.csv)
  if (( $(echo "$Taupunkt > $Temp" | bc -l) )); then
    Taupunkt=$Temp
  fi
  curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Taupunkt" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Taupunkt_${zaehler}/state"
  Wolken=$(awk -v varzaehler=$zeile 'BEGIN { FS=";" } NR==varzaehler {print $28}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Wolken" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Wolken_${zaehler}/state"
done
curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_min" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Temp_min/state"
curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_max" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_h_Temp_max/state"
# Tagesvorhersage
Temp_max_max=-100
Temp_min_min=100
datum_heute=$(date +%d.%m.%y)
datum_morgen=$(date -d "+1 days" +%d.%m.%y)
zeile_heute_18uhr=$(awk -v vardatum=$datum_heute 'BEGIN { FS=";" } ($1 ~ vardatum && $2 ~ /18:00/) {print NR}' weather.csv)
zeile_morgen_6uhr=$(awk -v vardatum=$datum_morgen 'BEGIN { FS=";" } ($1 ~ vardatum && $2 ~ /06:00/) {print NR}' weather.csv)
zeile_morgen_0uhr=$((zeile_morgen_6uhr-2))
# Schleife 6 Tages-Vorhersagen
#   Eintraege naechster Tag  0:00: Regenwahrscheinlichkeit verg. 24h
#   Eintraege naechster Tag  6:00: Temp_min, Regen, Sonnenstunden
#   Eintraege aktueller Tag 18:00: Temp_max
for zaehler in {0..5}
do
  zeile=$(($zeile_morgen_0uhr+8*$zaehler))
  Regenwahrscheinlichkeit=$(awk -v varzeile=$zeile 'BEGIN { FS=";" } NR==varzeile {print $22}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Regenwahrscheinlichkeit" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Regenwahrscheinlichkeit_${zaehler}/state"
  zeile=$(($zeile_morgen_6uhr+8*$zaehler))
  Temp_min=$(awk -v varzeile=$zeile -v varoffset=$temp_offset 'BEGIN { FS=";" } NR==varzeile {print $6+varoffset}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_min" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tempmin_${zaehler}/state"
  if (( $(echo "$Temp_min < $Temp_min_min" | bc -l) )); then
    Temp_min_min=$Temp_min
  fi
  Regen=$(awk -v varzeile=$zeile 'BEGIN { FS=";" } NR==varzeile {print $19}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Regen" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Regen_${zaehler}/state"
  Sonnenstunden=$(awk -v varzeile=$zeile 'BEGIN { FS=";" } NR==varzeile {print $34}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Sonnenstunden" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Sonnenstunden_${zaehler}/state"
  zeile=$(($zeile_heute_18uhr+8*$zaehler))
  if [ $zeile -gt 6 ]; then
    tempzeile=$(($zeile-3))
	wolken1=$(awk -v varzeile=$tempzeile 'BEGIN { FS=";" } NR==varzeile {print $28}' weather.csv)
	tempzeile=$(($zeile-2))
	wolken2=$(awk -v varzeile=$tempzeile 'BEGIN { FS=";" } NR==varzeile {print $28}' weather.csv)
	tempzeile=$(($zeile-1))
	wolken3=$(awk -v varzeile=$tempzeile 'BEGIN { FS=";" } NR==varzeile {print $28}' weather.csv)
	Wolken=$(awk "BEGIN {OFMT=\"%.0f\"; print ($wolken1+$wolken2+$wolken3)/3;}")
	curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Wolken" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Wolken_${zaehler}/state"
  fi
  Temp_max=$(awk -v varzeile=$zeile -v varoffset=$temp_offset 'BEGIN { FS=";" } NR==varzeile {print $5+varoffset}' weather.csv)
    curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_max" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tempmax_${zaehler}/state"
  if (( $(echo "$Temp_max > $Temp_max_max" | bc -l) )); then
    Temp_max_max=$Temp_max
  fi
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
curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_min_min" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tempmin_min/state"
curl -s -X PUT --header "Content-Type: text/plain" --header "Accept: application/json" -d "$Temp_max_max" "http://openhabianpi:8080/rest/items/DWD_Vorhersage_d_Tempmax_max/state"
