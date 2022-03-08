cd initramfs
call initramfs.cmd || exit /b 1
cd ..

cd efi
call efi.cmd || exit /b 1
cd ..

cd fat32
call fat32.cmd || exit /b 1
cd ..