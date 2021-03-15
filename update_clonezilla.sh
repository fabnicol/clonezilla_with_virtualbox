#!/bin/bash
mkdir -p  /boot
apt update -yq
apt upgrade -yq <<< 'N'
apt install apt-utils
# We take the oldest supported 5.x linux headers, modules and images
# Sometimes the most recent ones are not aligned with VB wrt. building.
# Sometimes current CloneZilla kernel has no corresponding apt headers
# So replacing with common base for which headers are available and
# compilation issues probably lesser
headers="$(apt-cache search ^linux-headers-[5-9]\.[0-9]+.*generic \
| grep -v unsigned | head -n1 | cut -f 1 -d' ')"
kernel="$(apt-cache  search ^linux-image-[5-9]\.[0-9]+.*generic   \
| grep -v unsigned | head -n1 | cut -f 1 -d' ')"
modules="$(apt-cache search ^linux-modules-[5-9]\.[0-9]+.*generic \
| grep -v unsigned | head -n1 | cut -f 1 -d' ')"
if [ -z "${kernel}" ] || [ -z "${modules}" ] \
|| [ -z "${headers}" ]
then
    echo "[ERR] Could not find adequate linux kernel"
    echo "      The following cached list was searched:"
    echo "$(apt-cache search ^linux-headers-[5-9]\.[0-9]+.*generic)"
    exit 6
else
    kernel_version="$(sed 's/linux-image-//' <<< ${kernel})"
    if [ -z "${kernel_version}" ]
    then
        echo "[ERR] Could not get kernel version from filename."
	echo "      Aborting."
	exit 8
    fi
    echo "[MSG] Found kernel headers: ${headers}"
    sleep 7
fi
echo "-------------------------"
echo
echo "[MSG] Kernel version=${kernel_version}"
echo "[MSG] headers: ${headers}"
echo "[MSG] kernel: ${kernel}"
echo "[MSG] modules: ${modules}"
echo 
echo "------------------------"
sleep 7
apt install -qy "${headers}"
apt install -qy "${kernel}"
apt install -qy "${modules}"
apt install -qy build-essential gcc <<< "N"
apt install -y virtualbox-sources virtualbox-modules virtualbox-dkms
apt install -y virtualbox
apt install -y virtualbox-guest-additions-iso
mount -oloop /usr/share/virtualbox/VBoxGuestAdditions.iso /mnt
cd /mnt || exit 2
if ! [ -f VBoxLinuxAdditions.run ] 
then
    echo "[ERR] No VBoxLinuxAdditions.run file!"
    exit 3
fi    
/bin/bash VBoxLinuxAdditions.run
if ! [ -e /sbin/rcvboxadd ] 
then
    echo "[ERR] No /sbin/rcvboxadd!"
    exit 3
fi  
if ! /sbin/rcvboxadd quicksetup ${kernel_version}
then
    echo "[ERR] Could not create vbox guest additions module"
    exit 3
fi
cd / || exit 2
mkdir -p /home/partimag/image
umount /mnt
apt autoremove -y -q
exit
