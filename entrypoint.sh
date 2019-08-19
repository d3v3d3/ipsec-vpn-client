#!/bin/sh

exiterr()  { echo "Error: $1" >&2; exit 1; }

if [ ! -f "/.dockerenv" ]; then
  exiterr "Do NOT run this script outside Docker container."
fi

if [ -z "$VPN_IPSEC_PSK" ] || [ -z "$VPN_USER" ] || [ -z "$VPN_PASSWORD" ]; then
  exiterr "All VPN credentials must be specified. Edit your 'env' file and re-enter them."
fi

if printf '%s' "$VPN_IPSEC_PSK $VPN_USER $VPN_PASSWORD" | LC_ALL=C grep -q '[^ -~]\+'; then
  exiterr "VPN credentials must not contain non-ASCII characters."
fi

case "$VPN_IPSEC_PSK $VPN_USER $VPN_PASSWORD" in
  *[\\\"\']*)
    exiterr "VPN credentials must not contain these special characters: \\ \" '"
    ;;
esac

# Create Stronswan config
cat > /etc/ipsec.conf <<EOF
# ipsec.conf - strongSwan IPsec configuration file

# basic configuration

config setup
  # strictcrlpolicy=yes
  # uniqueids = no

# Add connections here.

# Sample VPN connections

conn %default
  ikelifetime=60m
  keylife=20m
  rekeymargin=3m
  keyingtries=1
  keyexchange=ikev1
  authby=secret
  ike=aes128-sha1-modp1024,3des-sha1-modp1024!
  esp=aes128-sha1-modp1024,3des-sha1-modp1024!

conn myvpn
  keyexchange=ikev1
  left=%defaultroute
  auto=add
  authby=secret
  type=transport
  leftprotoport=17/1701
  rightprotoport=17/1701
  right=$VPN_PUBLIC_IP
  rightid=%any
EOF

cat > /etc/ipsec.secrets <<EOF
: PSK "$VPN_IPSEC_PSK"
EOF

chmod 600 /etc/ipsec.secrets

# Create xl2tpd config
cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[lac myvpn]
lns = $VPN_PUBLIC_IP
ppp debug = yes
pppoptfile = /etc/ppp/options.l2tpd.client
length bit = yes
EOF

# Set xl2tpd options
cat > /etc/ppp/options.l2tpd.client <<EOF
ipcp-accept-local
ipcp-accept-remote
refuse-eap
require-chap
noccp
noauth
mtu 1280
mru 1280
noipdefault
defaultroute
usepeerdns
connect-delay 5000
name $VPN_USER
password $VPN_PASSWORD
EOF

chmod 600 /etc/ppp/options.l2tpd.client

# Create xl2tpd control file:
mkdir -p /var/run/xl2tpd
touch /var/run/xl2tpd/l2tp-control

# Restart services:
service ipsec restart
service xl2tpd restart

# Start the IPsec connection:
ipsec up myvpn

# Start the L2TP connection:
echo "c myvpn" > /var/run/xl2tpd/l2tp-control

# Setup routes
GW="$(ip route | grep default | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")"
INTERNAL_HOST_IP=${VPN_INTERNAL_HOST_IP:-''}
[ -z "$INTERNAL_HOST_IP" ] && INTERNAL_HOST_IP=$(getent hosts host.docker.internal | awk '{ print $1 }')

INTERNAL_GW_IP=${VPN_INTERNAL_GW_IP:-''}
[ -z "$INTERNAL_GW_IP" ] && INTERNAL_GW_IP=$(getent hosts gateway.docker.internal | awk '{ print $1 }')

route add $INTERNAL_HOST_IP gw $GW
route add $INTERNAL_GW_IP gw $GW
route add $VPN_PUBLIC_IP gw $GW
sleep 10
route add default dev ppp0

trap : TERM INT
tail -f /dev/null & wait