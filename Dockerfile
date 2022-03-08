FROM alpine:3.15.0 AS build

ARG ARCH
ARG KERNEL_VERSION
ARG KERNEL_CONFIG=minimal
ARG BUSYBOX_VERSION
ARG BUSYBOX_CONFIG=minimal

ENV ARCH=$ARCH
ENV KERNEL_VERSION=$KERNEL_VERSION
ENV KERNEL_CONFIG=$KERNEL_CONFIG
ENV BUSYBOX_VERSION=$BUSYBOX_VERSION
ENV BUSYBOX_CONFIG=$BUSYBOX_CONFIG

ADD build.sh /build/build.sh
ADD init.sh /build/initramfs/etc/init.d/rcS
ADD inittab /build/initramfs/etc/inittab
ADD hotplug.sh /build/initramfs/sbin/hotplug
ADD udhcpc.sh /build/initramfs/usr/share/udhcpc/default.script
RUN apk add busybox-initscripts
RUN sh -c /build/build.sh


FROM scratch AS export
COPY --from=build /initramfs.cpio.gz .