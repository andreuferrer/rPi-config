#!/bin/bash
#
# This script has been tested on raspbian jessie lite image (March 2017)
#
wifiSSID="rPi3"
wifiRANGE='10.1.1'
if [ "$EUID" -ne 0 ]; then echo "Must be root";	exit; fi

[[ $# -eq 1 ]] && wifiSSID=$1
echo $wifiSSID

apt-get remove --purge hostapd -y
apt-get remove --purge dnsmasq -y
apt-get install hostapd dnsmasq -y
apt-get install iptables-persistent -y
apt-get update -y
apt-get dist-upgrade -y

file='/etc/systemd/system/hostapd.service'
[[ -f $file && ! -f $file.old ]] && mv $file $file.old
cat > $file <<EOF
[Unit]
Description=Hostapd IEEE 802.11 Access Point
After=sys-subsystem-net-devices-wlan0.device
BindsTo=sys-subsystem-net-devices-wlan0.device
[Service]
Type=forking
PIDFile=/var/run/hostapd.pid
ExecStart=/usr/sbin/hostapd -B /etc/hostapd/hostapd.conf -P /var/run/hostapd.pid
[Install]
WantedBy=multi-user.target
EOF

file='/etc/dhcp/dhcpd.conf'
[[ -f $file && ! -f $file.old ]] && mv $file $file.old
cat >> $file <<EOF
# Sample configuration file for ISC dhcpd for Debian
ddns-update-style none;
#option domain-name "example.org";
#option domain-name-servers ns1.example.org, ns2.example.org;
 
default-lease-time 86400;
max-lease-time 604800;
authoritative;
 
one-lease-per-client true;
get-lease-hostnames true;
option domain-name "local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
log-facility local0;
#log-facility local7;
 
subnet $wifiRANGE.0 netmask 255.255.255.0 {
range $wifiRANGE.2 $wifiRANGE.100;
option broadcast-address $wifiRANGE.255;
option routers $wifiRANGE.1;
option domain-name "local";
option domain-name-servers 8.8.8.8, 8.8.4.4;
}
EOF

file='/etc/dnsmasq.conf'
[[ -f $file && ! -f $file.old ]] && mv $file $file.old
cat > $file <<EOF
interface=wlan0
dhcp-range=$wifiRANGE.10,$wifiRANGE.128,255.255.255.0,12h
EOF

file='/etc/hostapd/hostapd.conf'
[[ -f $file && ! -f $file.old ]] && mv $file $file.old
cat > $file <<EOF
ssid=$wifiSSID
ignore_broadcast_ssid=0
interface=wlan0
channel=6
hw_mode=g
country_code=ES
ieee80211n=1
wmm_enabled=1
ht_capab=[HT40][SHORT-GI-20][DSSS_CCK-40]
ignore_broadcast_ssid=0
ap_max_inactivity=21600
auth_algs=1
macaddr_acl=0
#accept_mac_file=/etc/hostapd/hostapd.accept
wpa=0
EOF
echo "SSID of wifi lan is '"$wifiSSID"' and it is visible. If you want, modify this state with script"
echo "Network open wifi, without password protection. If you want, modify this state with script"
file='/etc/default/hostapd'
[[ -f $file && ! -f $file.old ]] && cp $file $file.old
sed -ie 's/#DAEMON_CONF=""/DAEMON_CONF="\/etc\/hostapd\/hostapd.conf"/g' $file
file='/etc/init.d/hostapd'
[[ -f $file && ! -f $file.old ]] && cp $file $file.old
sed -ie 's/DAEMON_CONF=/DAEMON_CONF=\/etc\/hostapd\/hostapd.conf/g' $file

file='/etc/network/interfaces'
[[ -f $file && ! -f $file.old ]] && mv $file $file.old
cat > $file <<EOF
# Source-directory /etc/network/interfaces
# For static IP, consult /etc/dhcpcd.conf
auto lo
iface lo inet loopback
iface eth0 inet dhcp
allow-hotplug wlan0
iface wlan0 inet static
	address $wifiRANGE.1
	netmask 255.255.255.0
	network $wifiRANGE.0
	broadcast $wifiRANGE.255
#wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
up iptables-restore < /etc/iptables.ipv4.nat
EOF
echo "RPi3 has been configured as a router with IP "$wifiRANGE.1
echo "RPi3 automatically assign IPs  in the range "$wifiRANGE".2 to "$wifiRANGE".100"
file='/etc/dhcpcd.conf'
[[ -f $file && ! -f $file.old ]] && cp $file $file.old
echo "denyinterfaces wlan0" >> $file
file='/etc/sysctl.conf'
[[ -f $file && ! -f $file.old ]] && cp $file $file.old
echo "net.ipv4.ip_forward=1" >>  $file
sudo sh -c "echo 1 > /proc/sys/net/ipv4/ip_forward "
# sudo iptables -t nat -A POSTROUTING -j MASQUERADE
iptables -t nat -A POSTROUTING -o -j MASQUERADE
iptables -A FORWARD -i eth0 -o wlan0 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -i wlan0 -o eth0 -j ACCEPT


systemctl enable hostapd
systemctl enable dnsmasq.service

apt-get clean -y
apt-get autoremove -y

echo -e "\nAll done! \nPlease: sudo reboot"
