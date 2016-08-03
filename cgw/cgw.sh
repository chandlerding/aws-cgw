#!/bin/sh

#echo "http://dl-4.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
#apk update && apk add strongswan bird iptables

setup_env () {

[ "x${VGW1}" != "x" ] || exec echo "\$VGW1 not set, exiting."
[ "x${VGW2}" != "x" ] || exec echo "\$VGW2 not set, exiting."
[ "x${PSK1}" != "x" ] || exec echo "\$PSK1 not set, exiting."
[ "x${PSK2}" != "x" ] || exec echo "\$PSK2 not set, exiting."
[ "x${VTI1_LOCAL}" != "x" ] || exec echo "\$VTI1_LOCAL not set, exiting."
[ "x${VTI2_LOCAL}" != "x" ] || exec echo "\$VTI2_LOCAL not set, exiting."
[ "x${VTI1_REMOTE}" != "x" ] || exec echo "\$VTI1_REMOTE not set, exiting."
[ "x${VTI2_REMOTE}" != "x" ] || exec echo "\$VTI2_REMOTE not set, exiting."
[ "x${LOCAL_ASN}" != "x" ] || exec echo "\$LOCAL_ASN not set, exiting."
[ "x${REMOTE_ASN}" != "x" ] || exec echo "\$REMOTE_ASN not set, exiting."

# LOCAL_IP=`grep "${HOSTNAME}" /etc/hosts | awk '{print $1}' `
GW_IP=`ip route|grep default|awk '{print $3}'`

}

setup_vti () {
	ip tunnel add vti1 remote ${VGW1} mode vti key 8
	ip addr add ${VTI1_LOCAL}/30 dev vti1
	ip link set vti1 up mtu 1427

	ip tunnel add vti2 remote ${VGW2} mode vti key 16
	ip addr add ${VTI2_LOCAL}/30 dev vti2
	ip link set vti2 up mtu 1427

	sleep 3;

	sysctl -w net.ipv4.conf.vti2.rp_filter=0
	sysctl -w net.ipv4.conf.vti2.disable_policy=1
	sysctl -w net.ipv4.conf.vti1.rp_filter=0
	sysctl -w net.ipv4.conf.vti1.disable_policy=1
}

config_ipsec () {
	sed -e 's/# install_routes = yes/install_routes = no/' -i /etc/strongswan.d/charon.conf

cat <<EOF > /etc/ipsec.conf
# ipsec.conf - strongSwan IPsec configuration file
config setup
	charondebug = "cfg 1, ike 1, net 0"	

conn %default
	leftsubnet=0.0.0.0/0    
        rightsubnet=0.0.0.0/0    
        leftauth=psk            
        rightauth=psk           
        ike=aes128-sha1-modp1024 
        esp=aes128-sha1-modp1024 
        ikelifetime=8h           
        keylife=1h               
        keyexchange=ikev1        
        dpddelay=10              
        dpdtimeout=30            
        dpdaction=restart
	mobike=no
        auto=start

conn vti1
	right=${VGW1}
	mark=8
	
conn vti2
	right=${VGW2}
	mark=16
EOF

cat <<EOF > /etc/ipsec.secrets
* ${VGW1} : PSK ${PSK1}
* ${VGW2} : PSK ${PSK2}
EOF
}

config_bird () {

cat <<EOF > /etc/bird.conf
log stderr all;
debug protocols { states, routes, filters, interfaces } ;

protocol kernel {
  export all;
  persist;
}

protocol device {
  scan time 10;    # Scan interfaces every 2 seconds
}

# Include directly connected network
protocol direct {
	interface "eth*","vti*";
}

define local_asn=${LOCAL_ASN} ;
define remote_asn=${REMOTE_ASN} ;

filter tagit {
  if source = RTS_BGP then {
        bgp_community.add((local_asn,100));
  }
  accept;
}

filter as_override {
  if (local_asn,100) ~ bgp_community then {
     bgp_path.empty;
     bgp_path.prepend(local_asn);
     accept;
  }
  reject;
}

protocol bgp rr1 {
  neighbor ${GW_IP} as local_asn;
  local as local_asn;
  next hop self;
  hold time 30;
  import filter tagit;
  export where source = RTS_BGP;
}

protocol bgp vti1 {
  neighbor ${VTI1_REMOTE} as remote_asn;
  local ${VTI1_LOCAL} as local_asn;
  next hop self;
  hold time 30;
  import all;
  export filter as_override;
}

protocol bgp vti2 {
  neighbor ${VTI2_REMOTE} as remote_asn;
  local ${VTI2_LOCAL} as local_asn;
  next hop self;
  hold time 30;
  import all;
  export filter as_override;
}
EOF

}

if ! [ -f /var/lock/cgw.lock ]; then
	setup_env;
	config_ipsec;
	config_bird;
	touch /var/lock/cgw.lock
fi
	setup_vti;
	bird -f &
	ipsec start --nofork
