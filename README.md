## neutrinovps
Standalone openvpn+telegramproxy+sslh VPS installer

This script will setup your own VPS in no more than a minute with OpenVPN, Telegram MTProxy and sslh to leak through walls like neutrino. It implements some basic firewall rules, disables ipv6, disables ping response to prevent 2sided-ping tunnel detection, adjusts MSS\MTU for OpenVPN and adds some DPI protection to MTProxy ('dd' suffix).

### Installation
Run the script:

`wget https://git.io/neutrinovps -O setup.sh && bash setup.sh`

Once it ends, you will get .ovpn config file and Telegram proxy link.

### Credits
OpenVPN - https://github.com/Nyr/openvpn-install/
MTProxy - https://github.com/alexbers/mtprotoproxy
