#!/usr/bin/env sh

echo Building EFI boot partition ...
cd /build || exit

mkdir image

mkdir -p image/EFI/BOOT

mkdir -p image/legal/grub
cp grub/SOURCE image/legal/grub/source
cp grub/VERSION image/legal/grub/version
cp grub/LICENSE image/legal/grub/LICENSE

sed -e "s/\$NANOOS_VERSION/$NANOOS_VERSION/g" grub.cfg > image/EFI/BOOT/grub.cfg
cp kernel/bzImage image/EFI/BOOT/linux
cp initramfs.cpio.gz image/EFI/BOOT/initrd
cp grub/*.efi image/EFI/BOOT || exit

mkdir -p image/legal/kernel
echo "https://github.com/vmify/kernel/archive/refs/tags/$KERNEL_VERSION.tar.gz" > image/legal/kernel/source
echo "$KERNEL_VERSION" > image/legal/kernel/version
cp kernel/LICENSE image/legal/kernel

mkdir -p image/legal/busybox
echo "https://github.com/vmify/busybox/archive/refs/tags/$BUSYBOX_VERSION.tar.gz" > image/legal/busybox/source
echo "$BUSYBOX_VERSION" > image/legal/busybox/version
cp busybox/LICENSE image/legal/busybox

mkdir -p image/legal/nanoos
echo "https://github.com/vmify/nanoos/archive/refs/tags/$NANOOS_VERSION.tar.gz" > image/legal/nanoos/source
echo "$NANOOS_VERSION" > image/legal/nanoos/version
cp LICENSE image/legal/nanoos

cd image

tar -czvf /nanoos.tar.gz *
