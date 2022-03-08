#!/bin/sh
RESOLV_CONF="/etc/resolv.conf"

NETMASK=""
[ -n "$subnet" ] && NETMASK="netmask $subnet"
BROADCAST="broadcast +"
[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"

case "$1" in
deconfig)
  echo "$interface: setting IP address to 0.0.0.0"
  ifconfig $interface 0.0.0.0
  ;;

renew | bound)
  echo "$interface: setting IP address to $ip"
  ifconfig $interface $ip $NETMASK $BROADCAST

  ROUTER_OK=0
  if [ -n "$router" ]; then
    metric=0
    for i in $router; do
      echo "$interface: adding router $i"
      route add default gw $i dev $interface metric $((metric++))
      ROUTER_OK=1
    done
  fi
  if [ $ROUTER_OK -eq 0 ]; then
    echo "ERROR: DHCP server didn't return routers!"
    exit 1
  fi

  echo -n >$RESOLV_CONF
  [ -n "$domain" ] && echo "search $domain" >>$RESOLV_CONF

  DNS_OK=0
  for i in $dns; do
    echo "$interface: adding DNS server $i"
    echo "nameserver $i" >>$RESOLV_CONF
    DNS_OK=1
  done
  if [ $DNS_OK -eq 0 ]; then
    echo "ERROR: DHCP server didn't return DNS servers!"
    exit 1
  fi
  ;;
esac

exit 0
