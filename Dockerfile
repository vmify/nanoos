ARG ARCH
ARG NANOOS_VERSION
ARG KERNEL_VERSION
ARG BUSYBOX_VERSION

FROM alpine:3.15.0 AS initramfs

ENV ARCH=$ARCH
ENV KERNEL_VERSION=$KERNEL_VERSION
ENV BUSYBOX_VERSION=$BUSYBOX_VERSION

ADD build-initramfs.sh /build/build.sh
ADD kernel.tar.gz /build/initramfs
ADD busybox.tar.gz /build/initramfs/bin
ADD initramfs/init.sh /build/initramfs/etc/init.d/rcS
ADD initramfs/inittab /build/initramfs/etc/inittab
ADD initramfs/hotplug.sh /build/initramfs/sbin/hotplug
ADD initramfs/udhcpc.sh /build/initramfs/usr/share/udhcpc/default.script
RUN apk add busybox-initscripts
RUN sh -c /build/build.sh


FROM alpine:edge AS efi

ENV ARCH=$ARCH
ENV NANOOS_VERSION=$NANOOS_VERSION
ENV KERNEL_VERSION=$KERNEL_VERSION

ADD build-efi.sh /build/build.sh
ADD kernel.tar.gz /build
COPY --from=initramfs /initramfs.cpio.gz /build
RUN apk add efi-mkuki gummiboot-efistub file
RUN sh -c /build/build.sh


FROM scratch AS export
COPY --from=efi /nanoos.efi .