#!/usr/bin/env sh

echo Building initramfs ...
cd /build/initramfs || exit

rm bzImage
rm LICENSE
rm bin/LICENSE

mkdir -p lib/mdev
mkdir -p usr/sbin
mkdir usr/bin
mkdir proc
mkdir sys
mkdir mnt
mkdir dev
mkdir run
mkdir tmp
mkdir -p /var/lock
mkdir app
cp /etc/group etc
cp /etc/passwd etc
echo '$MODALIAS=.*	root:root	0666	@modprobe -v -b "$MODALIAS"' > etc/mdev.conf
chmod +x sbin/hotplug
chmod +x usr/share/udhcpc/default.script
chmod +x etc/init.d/rcS
echo "$NANOOS_VERSION" > /etc/nanoos.version

chroot . /bin/busybox --install -s
ln -s /sbin/init init

echo -e "PWRF poweroff\nPWRB reboot\n" > etc/acpid.conf
mkdir etc/acpi
ln -s /sbin/poweroff etc/acpi/poweroff
ln -s /sbin/reboot etc/acpi/reboot

echo Packaging initramfs ...
find . | cpio -o -H newc | gzip > /initramfs.cpio.gz