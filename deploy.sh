#!/bin/bash
cp -f ./limits.conf /etc/security/limits.conf
cp -f ./sysctl.conf /etc/sysctl.conf
echo 10000000 > /proc/sys/fs/file-max
echo 5 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse
echo 5 > /proc/sys/net/ipv4/tcp_keepalive_probes
echo 30 > /proc/sys/net/ipv4/tcp_keepalive_intvl
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout

# deprecated or removed (depending on arch)
#echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle

# only use if shared environment or needing QoS
#/sbin/modprobe tcp_cubic

echo
en_interface=$(ifconfig | awk '/^en/ {print $1}' | tr -d ':')
echo "Updating txqueuelen for device $en_interface..."
ifconfig $en_interface txqueuelen 5000
echo

# grab official ookla speedtest package from repo
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash

ubuntu_codename=$(lsb_release -cs)
if [ "$ubuntu_codename" = "noble" ]; then
    echo "Ubuntu Noble detected, replacing with 'jammy' in Ookla repository list"
    sudo sed -i 's/noble/jammy/g' /etc/apt/sources.list.d/ookla_speedtest-cli.list
else
    echo "Running a Ookla supported release, no changes needed to repository list"
fi

echo
apt-get update
apt-get install speedtest
ulimit -n 1000000

#WRAP UP
echo
echo "All kernel, TCP, and file descriptor tweaks have been successfully applied if no errors appear. speedtest-cli installed."
echo "You may now reboot."
echo
