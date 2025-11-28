#!/bin/bash

# clean out any old journalctl logs so we have space to do stuff

sudo journalctl --vacuum-size 10M

# install necessary packages

sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt autoremove -y
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt update -y
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt full-upgrade -y
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt install libcurl3-gnutls-dev build-essential vim wget libsodium-dev flex bison clang unzip libc6-dev-i386 gcc-12 dwarves libelf-dev pkg-config m4 libpcap-dev net-tools libbpf-dev libxdp-dev xdp-tools -y
sudo DUBAIN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt install dwarves linux-headers-`uname -r` linux-tools-`uname -r` -y
sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt autoremove -y

sudo cp /sys/kernel/btf/vmlinux /usr/lib/modules/`uname -r`/build/

# install proton module

make
sudo mkdir -p /lib/modules/`uname -r`/kernel/net/proton
sudo mv proton.ko /lib/modules/`uname -r`/kernel/net/proton

# setup proton module to load on reboot

cp /etc/modules ./modules.txt
echo "proton" >> modules.txt
sudo mv modules.txt /etc/modules
sudo depmod
