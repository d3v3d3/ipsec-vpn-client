# IPSEC L2TP VPN client

This image is designed for local use to provide a connection to other (local) containers.

## Required Environment Vars:

| name | value |
| --- | --- |
| VPN_PUBLIC_IP | vpn public IP |
| VPN_IPSEC_PSK | secret |
| VPN_USER | username |
| VPN_PASSWORD | password |

## Docker Compose Example (Docker for Mac)

```YML
version: "3.7"

services:
  vpn:
    image: d3v3d3/ipsec-vpn-client
    environment:
      - .env
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/ppp
      - /dev/net/tun
    networks:
      - vpn
  busybox:
    image: busybox
    network_mode: "service:vpn"
    depends_on: 
      - vpn
    command: sh -c "wget -qO- http://ipv4.icanhazip.com; echo"

networks:
  vpn:
```

## Credits
- https://github.com/hwdsl2/docker-ipsec-vpn-server
- https://github.com/hwdsl2/setup-ipsec-vpn/blob/master/docs/clients.md#configure-linux-vpn-clients-using-the-command-line