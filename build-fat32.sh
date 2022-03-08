#!/usr/bin/env sh

echo Building EFI boot partition ...
cd /build || exit

# 32 MB is the official smallest size allowed by FAT32
# While QEMU recognizes smaller ones, AWS doesn't and fails to boot
# 32 MB is more than enough to accommodate our EFI PE executable containing our kernel, cmdline and initramfs
FAT32_KB=32768

efi=nanoos.efi
img=/nanoos.fat32

if [ "$ARCH" = "x64" ]; then
  boot=bootx64.efi
else
  boot=bootaa64.efi
fi

dd if=/dev/zero of=$img bs=1K count=$FAT32_KB
mkfs -t vfat $img
mkdir image


mount -t auto -o loop $img image

mkdir -p image/EFI/BOOT
cp $efi image/EFI/BOOT/$boot || exit

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

umount image


echo Verifying FAT32 boot partition image ...
fsck.vfat -r -f -v -l -n $img || exit
gzip $img