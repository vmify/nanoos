@echo off
setlocal

set ARCH=%1
set DOCKER_ARCH=%2
set NANOOS_VERSION=0.0.0

FOR /F "tokens=*" %%i in ('type dependencies.conf') do SET %%i

curl -L -C - -o grub.tar.gz https://github.com/vmify/grub/releases/download/%GRUB_VERSION%/grub-%ARCH%-%GRUB_VERSION%.tar.gz
curl -L -C - -o kernel.tar.gz https://github.com/vmify/kernel/releases/download/%KERNEL_VERSION%/kernel-minimal-%ARCH%-%KERNEL_VERSION%.tar.gz
curl -L -C - -o busybox.tar.gz https://github.com/vmify/busybox/releases/download/%BUSYBOX_VERSION%/busybox-minimal-%ARCH%-%BUSYBOX_VERSION%.tar.gz

docker buildx build --platform=linux/%DOCKER_ARCH% --build-arg ARCH=%ARCH% --build-arg NANOOS_VERSION=%NANOOS_VERSION% --build-arg KERNEL_VERSION=%KERNEL_VERSION% --build-arg BUSYBOX_VERSION=%BUSYBOX_VERSION% --progress=plain --output type=local,dest=. -f Dockerfile-initramfs .
docker buildx build --build-arg ARCH=%ARCH% --build-arg NANOOS_VERSION=%NANOOS_VERSION% --build-arg GRUB_VERSION=%GRUB_VERSION% --build-arg KERNEL_VERSION=%KERNEL_VERSION% --build-arg BUSYBOX_VERSION=%BUSYBOX_VERSION% --progress=plain -t fat32-build -f Dockerfile-fat32 .
docker run --privileged --name fat32-run fat32-build
docker cp fat32-run:/nanoos.tar.gz .
docker container rm fat32-run
docker image rm fat32-build

copy nanoos.tar.gz ..\vmify-master\vmify\build\nanoos\nanoos-%ARCH%.tar.gz

endlocal
