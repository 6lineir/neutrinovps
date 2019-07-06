#!/bin/bash


### Firewall rules
sed -i 's/IPV6=yes/IPV6=no/g' /etc/default/ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow https


### mtproxy
# Create secret
SECRET=$(openssl rand -hex 16)
# Download custom proxy
git clone -b stable https://github.com/alexbers/mtprotoproxy.git /opt/mtproto_proxy; cd /opt/mtproto_proxy
# Update config
sed -i 's/"tg"/"default"/g' config.py
sed -i "s/00000000000000000000000000000000/$SECRET/g" config.py
sed -i_bak -e '/tg2/d' config.py
# Prepare files for daemon
# 1
cat <<EOT > /etc/systemd/system/mtproto-proxy.service
[Unit]
Description=Mtproto proxy worker
PartOf=mtproto-proxy.target
[Service]
Type=simple
ExecStart=/opt/mtproto_proxy/mtprotoproxy.py
EOT

# 2
cat <<EOT > /etc/systemd/system/mtproto-proxy.target
[Unit]
Description=Mtproto proxy
Wants=mtproto-proxy.service
[Install]
WantedBy=multi-user.target
EOT

# Configure daemon
sudo systemctl daemon-reload
sudo systemctl enable mtproto-proxy.target
sudo systemctl start mtproto-proxy.target


### openvpn
cd ~
# Download script
if grep -qs "Ubuntu 16.04" "/etc/os-release"; then
	wget https://git.io/vpn1604 -O openvpn-install.sh
else
    wget https://git.io/vpn -O openvpn-install.sh
fi
chmod +x openvpn-install.sh
# Prepare hack to run installation script
apt install expect tcl -y
# Hack file
cat <<"EOT" > wrapper.exp
#!/usr/bin/expect -f
set force_conservative 1
if {$force_conservative} {
	set send_slow {1 .1}
	proc send {ignore arg} {
		sleep .1
		exp_send -s -- $arg
	}
}
set timeout -1
spawn ./openvpn-install.sh
match_max 100000
expect -exact "First, provide the IPv4 address of the network interface"
send -- "\r"
expect -exact "Which protocol do you want for OpenVPN connections"
send -- \010
send -- "2\r"
expect -exact "What port do you want OpenVPN listening to"
send -- "\r"
expect -exact "Which DNS do you want to use with the VPN"
send -- \010
send -- "3\r"
expect -exact "Finally, tell me your name for the client certificate"
send -- \010\010\010\010\010\010
send -- "myovpn\r"
expect -exact "Press any key to continue"
send -- "\r"
expect eof
EOT

# Install openvpn
chmod +x wrapper.exp
./wrapper.exp
rm wrapper.exp
# Edit server config
cat <<EOT >> /etc/openvpn/server.conf
mssfix 1463
duplicate-cn
EOT

# Edit client config
sed -i 's/client/client\nmssfix 1463/g' myovpn.ovpn
sed -i 's/ 1194/ 443/g' myovpn.ovpn
# Adjust network rules
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A FORWARD -i tun+ -j ACCEPT
iptables -A INPUT -i tap+ -j ACCEPT
iptables -A FORWARD -i tap+ -j ACCEPT
# Install silent
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections
sudo apt-get -y install iptables-persistent
# Turn off external ip check
cat <<EOT >> /etc/sysctl.conf
net.ipv4.icmp_echo_ignore_all=1
EOT

# ?
sysctl -p
# Enable openvpn daemon
systemctl enable openvpn
systemctl start openvpn


### sslh port forwarding
# Install silent
echo sslh sslh/inetd_or_standalone select standalone | sudo debconf-set-selections
sudo apt install sslh -y
# Edit config
sed -i 's/Run=no/Run=yes/g' /etc/default/sslh

sed -i '/DAEMON_OPTS/d' /etc/default/sslh
echo 'DAEMON_OPTS="--user sslh --listen 0.0.0.0:443 --ssh 127.0.0.1:22 --openvpn 127.0.0.1:1194 --anyprot 127.0.0.1:3256 --timeout 5 --pidfile /var/run/sslh/sslh.pid"' >> /etc/default/sslh
# Enable sslh daemon
systemctl daemon-reload
systemctl enable sslh
systemctl restart sslh


### Finish
echo "################################ Setup finished! Deamon statuses: ###############################"
service mtproto-proxy status
service openvpn status
service sslh status
IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
echo "################# Setup finished! ssh, openvpn and mtproxy are listening 443 port. ##############
Telegram proxy: tg://proxy?server=$IP&port=443&secret=dd$SECRET (saved to mytgproxy.txt)
Openvpn client config in file 'myovpn.ovpn'"
echo "tg://proxy?server=$IP&port=443&secret=dd$SECRET" > mytgproxy.txt

### Firewall update
sudo ufw --force enable
