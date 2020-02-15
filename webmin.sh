#!/bin/bash
source en.locale.sh

##############################
# FUNCTIONS                  #
##############################

function survey {
ip link set wlan0 up
/sbin/iw dev wlan0 scan | egrep "SSID:" | sed -e "s/\tSSID: //" | \
tr ' ' '_' | grep . | awk '{print $1" -"}' >wlist
}

function join {
if [ ${#2} != "0" ]; then
if [ ${#2} -lt 8 ]; then echo $ERROR_TOOSHORT; return 1; fi
auth="psk=\"$2\""
else auth="key_mgmt=NONE"
fi

echo -e "ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev\n\
update_config=1\n\
country=IT\n\\n\
network={\n\
ssid=\"$1\"\n\
$auth\n}" >wpa_supplicant.conf

echo -n >wpa.log
killall wpa_supplicant 2>/dev/null
rm -rf /var/run/wpa_supplicant/*
timeout 10 /sbin/wpa_supplicant -c wpa_supplicant.conf -i wlan0 -f wpa.log
if cat wpa.log | grep -q -i "assoc-reject"; then echo $ERROR_BADPASS; return 1; fi
if cat wpa.log | grep -q -i "event-connected"; then
echo $INFO_GOODPASS
cp wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant.conf
return 0
fi
echo $ERROR_WPASUPPL
return 1
}

function restartnet {
echo >>/etc/network/interfaces
if ! grep -q "auto wlan0" /etc/network/interfaces; then echo "auto wlan0" >>/etc/network/interfaces; fi
if ! grep -q "iface wlan0 inet dhcp" /etc/network/interfaces; then echo "iface wlan0 inet dhcp" >>/etc/network/interfaces; fi
if ! grep -q "wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" /etc/network/interfaces
then echo "wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf" >>/etc/network/interfaces; fi
systemctl restart networking.service
if [ $? != "0" ]; then echo $ERROR_NETWORK; return 1; fi
echo "$INFO_SUCCESS $INFO_REBOOTING"
return 0
}

function finalize {
sed -i -e '/auto eth0/d' -e '/iface eth0 inet dhcp/d' /etc/network/interfaces
}

function restore {
echo -e "auto lo\niface lo inet loopback\n\nauto eth0\niface eth0 inet dhcp" >/etc/network/interfaces
echo -n >/etc/wpa_supplicant/wpa_supplicant.conf
}

##############################
# TUI                        #
##############################

/sbin/ifconfig wlan0 | grep -q -i "UP,BROADCAST,RUNNING,MULTICAST" && C="[$MENU_DONE]"

while true; do
act=$(dialog --no-cancel --output-fd 1 --menu "$MENU_TITLE" 13 50 7 \
   1 "$MENU_CONFIGURE $C" \
   2 "$MENU_RESTORELAN" \
   3 "$MENU_REBOOT" \
   4 "$MENU_SHUTDOWN" \
   5 "$MENU_QUIT");

case $act in

4) dialog --title "$CONFIRM_TITLE" --yesno "$CONFIRM_SHUTDOWN" 7 30
   if [ $? = "0" ]; then dialog --infobox $INFO_BYE 7 30; init 0; fi;;

3) dialog --title "$CONFIRM_TITLE" --yesno "$CONFIRM_REBOOT" 7 30
   if [ $? = "0" ]; then dialog --infobox "$INFO_BYE" 7 30; sync && /sbin/reboot; fi;;

5) clear
   exit 0;;

1) if [ ! -z "$C" ]; then
   dialog --title "$CONFIRM_TITLE" --yesno "$CONFIRM_RECONFIGURE" 10 60
   if [ $? = "0" ]; then dialog --infobox "$INFO_BYE" 7 30; restore; /sbin/init 0; fi
   continue; fi
   dialog --infobox "$INFO_SCANNING" 5 40; sleep 2
   survey
   ap=$(dialog --menu "$CONFIGURE_CHOOSEAP" 20 60 20 --output-fd 1 $(cat wlist))
   ap=$(echo $ap | tr '_' ' ')
   [ -z "$ap" ] && continue
   pw=$(dialog --output-fd 1 --inputbox "$CONFIGURE_PASSWORD" 8 80)
   dialog --infobox "$INFO_TRYING" 5 40
   re=$(join "$ap" "$pw"); E=$?
   dialog --timeout 6 --msgbox "$re" 5 40
   [ $E = "1" ] && continue
   dialog --infobox "$INFO_PLEASEWAIT" 5 40 &
   re=$(restartnet); E=$?
   dialog --timeout 6 --msgbox "$re" 5 60
   [ $E = "1" ] && { restore; continue; }
   finalize
   sync && /sbin/reboot;;

2) /sbin/ifconfig eth0 | grep -q -i "up\|running" && { dialog --msgbox "$RESTORELAN_ABORT" 7 30; continue; }
   dialog --title "$CONFIRM_TITLE" --yesno "$RESTORELAN_CONFIRM" 5 60
   if [ $? = "0" ]; then
   restore
   dialog --infobox "$INFO_REBOOTING" 5 60
   sync && /sbin/reboot
   else continue; fi;;

esac
done
