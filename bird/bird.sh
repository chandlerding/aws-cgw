#!/bin/sh

case "$1" in
    add|--add)
	[ $# = 3 ] || exec echo "$0 add peerip asn"

	cat <<EOF > "/etc/bird.d/$2.conf"
protocol bgp {
        local as $3;
        neighbor $2 as $3;
        rr client;
        import all;
        export where ( source = RTS_BGP || source = RTS_STATIC );
}
EOF
	birdc configure
         ;;
    del|--del)
	[ $# = 2 ] || exec echo "$0 add peerip asn"
	rm -f "/etc/bird.d/$2.conf"
	birdc configure
	;;
    *)
	echo "$0 add peerip asn"
	echo "$0 del peerip"
esac

