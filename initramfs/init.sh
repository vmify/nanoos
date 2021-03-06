#!/bin/ash

log() {
  echo "[$(date -u -Iseconds | tr 'T' ' ' | cut -d'+' -f1)] $1"
}


echo
log "VMify NanoOS r$(cat /etc/nanoos.version) booting ..."
[ "$NANOOS_DEBUG" = "1" ] && env

if [ "$NANOOS_DEBUG" != "1" ]; then
  log "Redirecting kernel output to syslog ..."
  # Silence kernel
  dmesg -n 1
  # Silence other unnecessarily verbose commands
  suppress_output='> /dev/null 2> /dev/null'
else
  suppress_output=''
fi



log "Setting up PATH ..."
export PATH=/sbin:/usr/sbin:/bin:/usr/bin



log "Mounting sys, proc and dev virtual filesystems ..."
mount -t sysfs -o nodev,noexec,nosuid sysfs /sys
mount -t proc -o nodev,noexec,nosuid proc /proc
mount -t devtmpfs -o nosuid,mode=0755 udev /dev
mkdir /dev/pts
mount -t devpts -o noexec,nosuid,gid=5,mode=0620 devpts /dev/pts
mkdir /dev/mqueue
mount -t mqueue -o noexec,nosuid,nodev mqueue /dev/mqueue
mkdir /dev/shm
mount -t tmpfs -o nodev,nosuid,noexec shm /dev/shm
ln -snf /proc/self/fd /dev/fd
ln -snf /proc/self/fd/0 /dev/stdin
ln -snf /proc/self/fd/1 /dev/stdout
ln -snf /proc/self/fd/2 /dev/stderr



if [ -f /proc/modules ]; then
  modules=1
fi
if [ "$modules" = "1" ]; then
  log "Loading drivers ..."
  # Silence modprobe to suppress confusing module not found messages for built-in modules
  eval "find /sys/ -name modalias | xargs sort -u | xargs -n 1 modprobe -q -s $suppress_output"
fi
[ "$NANOOS_DEBUG" = "1" ] && ls -l /dev



[ "$NANOOS_DEBUG" = "1" ] && lspci -mk
[ "$NANOOS_DEBUG" = "1" ] && cat /sys/devices/virtual/dmi/id/bios_version
if lspci -mk | grep -q '"ena"$'; then
  platform="aws"
  # Amazon Time Sync Service -> https://aws.amazon.com/blogs/aws/keeping-time-with-amazon-time-sync-service/
  ntp_server=169.254.169.123
  app_device=/dev/nvme0n1p2
  swap_device=/dev/nvme1n1
elif [ "$(cat /sys/devices/virtual/dmi/id/bios_version)" = "Google" ]; then
  platform="gcp"
  # Google Internal NTP Server -> https://cloud.google.com/compute/docs/instances/configure-ntp
  ntp_server=$(cat /proc/net/ipconfig/ntp_servers)
  app_device=/dev/sda2
  swap_device=/dev/sdb
else
  platform="qemu"
  ntp_server=0.amazon.pool.ntp.org
  app_device=/dev/vda2
  swap_device=/dev/vdb
fi
log "Detected platform: $platform"



# Not needed as it's already the default
# log "Optimizing disk IO performance ..."
# See https://wiki.ubuntu.com/Kernel/Reference/IOSchedulers
# echo "none" > /sys/block/$io_scheduler_device/queue/scheduler



if [ -b "$swap_device" ]; then
  log "Initializing swap ..."
  mkswap $swap_device > /dev/null
  swapon $swap_device
fi



log "Configuring networking ..."
lo_ip="127.0.0.1"
lo_hostname="localhost"
ifconfig lo $lo_ip
echo -e "$lo_ip"'\t'"$lo_hostname" > /etc/hosts
log "lo   : $lo_ip ($lo_hostname)"

eth0_ip=$(ifconfig eth0 | grep 'inet ' | cut -d ':' -f 2 | cut -d ' ' -f 1)
eth0_hostname=$(hostname)
echo -e "$eth0_ip"'\t'"$eth0_hostname" >> /etc/hosts
log "eth0 : $eth0_ip ($eth0_hostname)"
[ "$NANOOS_DEBUG" = "1" ] && cat /etc/hosts

dns=$(cat /proc/net/pnp | grep nameserver | cut -d ' ' -f 2)
echo "nameserver $dns" > /etc/resolv.conf
log "dns  : $dns"
[ "$NANOOS_DEBUG" = "1" ] && cat /proc/net/pnp



log "Mounting app partition read-only ..."
mount -t ext2 -r $app_device /app

if [ "$NANOOS_READONLY" != "1" ]; then
  log "Overlaying a read-write tmpfs ..."
  mkdir /app.tmpfs
  mount -t tmpfs -o rw,relatime tmpfs /app.tmpfs
  mkdir /app.tmpfs/upper
  mkdir /app.tmpfs/work
  mkdir /app.overlay
  mount -t overlay -o rw,lowerdir=/app,upperdir=/app.tmpfs/upper,workdir=/app.tmpfs/work overlay /app.overlay
  mount --bind /app.overlay /app
fi



log "Bind mounting /sys, /proc, /dev and /etc/hosts ..."
if [ "$NANOOS_READONLY" != "1" ]; then
  mkdir -p /app/sys
  mkdir -p /app/proc
  mkdir -p /app/dev
  mkdir -p /app/etc
  touch /app/etc/hosts
fi
mount --bind /sys /app/sys
mount --bind /proc /app/proc
mount --bind /dev /app/dev
mount --bind /etc/hosts /app/etc/hosts
[ "$NANOOS_DEBUG" = "1" ] && cat /proc/mounts



log "Tuning kernel parameters ..."
# Generate 'param=value' for all sysctl arguments passed in as NANOOS_SYSCTL_*='param=value'
eval_sysctl() {
  env_sysctl=$1
  echo -n "'${env_sysctl#*=}' "
}
env_sysctl_all=$(env | grep '^NANOOS_SYSCTL_')
eval_sysctls=$(for line in $env_sysctl_all; do eval_sysctl "$line"; done)
[ "$NANOOS_DEBUG" != "1" ] && sysctl_extra_args='-q'
eval "sysctl $sysctl_extra_args -w $eval_sysctls"
ulimit -HSn "$(cat /proc/sys/fs/file-max)"
ulimit -HSl unlimited



if [ "$modules" = "1" ]; then
  log "Freeing memory occupied by unused kernel modules ..."
  rm -Rf /lib/modules
  rm -Rf /legal

  log "Disabling kernel module loading ..."
  sysctl -w $sysctl_extra_args kernel.modules_disabled=1
  [ "$NANOOS_DEBUG" = "1" ] && lsmod
fi



log "Starting NTP daemon ..."
ntpd -p $ntp_server &



log "Starting ACPI daemon ..."
acpid -d &



log "NanoOS boot completed in $(cut -d ' ' -f 1 /proc/uptime)s"



[ "$NANOOS_DEBUG" = "1" ] && free
log "Launching $NANOOS_APP ..."
# Ensure env output is split by lines in for loops
IFS=$'\n'

# Generate NAME='VALUE' for all app environment variables passed in as NANOOS_ENV_ABC,NANOOS_ENV_XYZ,...
eval_env() {
  env_name=$(echo "$1" | cut -c 12- | cut -d '=' -f1)
  env_value=$(echo "$1" | cut -d '=' -f2)
  echo -n "$env_name='$env_value' "
}
env_env_all="$(env | grep '^NANOOS_ENV_')"
eval_envs="$(for line in $env_env_all; do eval_env "$line"; done)"

# Generate 'VALUE' for all list arguments passed in as LIST_0,LIST_1,...
eval_list() {
  value=$(echo "$1" | cut -d '=' -f2)
  echo -n "'$value' "
}

env_entrypoint_all=$(env | grep '^NANOOS_ENTRYPOINT_' | sort)
eval_entrypoint=$(for line in $env_entrypoint_all; do eval_list "$line"; done)

env_cmd_all=$(env | grep '^NANOOS_CMD_' | sort)
eval_cmd=$(for line in $env_cmd_all; do eval_list "$line"; done)

# Launch app entrypoint plus cmd in chroot with only its own set of environment variables
# Backgrounding is required for clean handling of acpi power events
eval "/usr/bin/env -i $eval_envs /usr/sbin/chroot /app $eval_entrypoint $eval_cmd &"
pid=$!

[ "$NANOOS_DEBUG" = "1" ] && ps
if [ "$NANOOS_REBOOT" = "1" ]; then
  # Reboot when app terminates
  ( (while kill -0 $pid 2> /dev/null; do sleep 1; done;) && /sbin/reboot) &
else
  # Power off when app terminates
  ( (while kill -0 $pid 2> /dev/null; do sleep 1; done;) && /sbin/poweroff) &
fi
