#!/usr/bin/env python
import sys
import argparse
import boto3
import xmltodict
from docker import Client


def peer_vpn( regionId, vpnId , host=None):
	ec2 = boto3.client('ec2',region_name=regionId)
	vpn = ec2.describe_vpn_connections( VpnConnectionIds=[vpnId] )['VpnConnections'][0]
	config = xmltodict.parse( vpn['CustomerGatewayConfiguration'] )
	cfg = {	"VGW1" 		: config['vpn_connection']['ipsec_tunnel'][0]['vpn_gateway']['tunnel_outside_address']['ip_address'] ,
		"VGW2" 		: config['vpn_connection']['ipsec_tunnel'][1]['vpn_gateway']['tunnel_outside_address']['ip_address'] ,
		"PSK1" 		: config['vpn_connection']['ipsec_tunnel'][0]['ike']['pre_shared_key'] ,
		"PSK2" 		: config['vpn_connection']['ipsec_tunnel'][1]['ike']['pre_shared_key'] ,
		"VTI1_LOCAL" 	: config['vpn_connection']['ipsec_tunnel'][0]['customer_gateway']['tunnel_inside_address']['ip_address'],
		"VTI2_LOCAL" 	: config['vpn_connection']['ipsec_tunnel'][1]['customer_gateway']['tunnel_inside_address']['ip_address'],
		"VTI1_REMOTE" 	: config['vpn_connection']['ipsec_tunnel'][0]['vpn_gateway']['tunnel_inside_address']['ip_address'],
		"VTI2_REMOTE" 	: config['vpn_connection']['ipsec_tunnel'][1]['vpn_gateway']['tunnel_inside_address']['ip_address'],
		"REMOTE_ASN" 	: config['vpn_connection']['ipsec_tunnel'][0]['vpn_gateway']['bgp']['asn'] ,
		"LOCAL_ASN" 	: config['vpn_connection']['ipsec_tunnel'][0]['customer_gateway']['bgp']['asn'] 
		}
	
	dock = Client(host);
	privileged = dock.create_host_config(privileged=True)
	container = dock.create_container( image='chandlerding/aws-cgw', hostname=vpn['VpnConnectionId'], 
		detach=True, environment=cfg, name=vpn['VpnConnectionId'], host_config=privileged )
	dock.start ( container = container.get('Id') )
	

def main () :
	parser = argparse.ArgumentParser(description = "Establish VPN connection with Amazon Web Service via docker container.")
	parser.add_argument("--region" , "-r", help = "specify which region (e.g. us-west-1) should we peer with.")
	parser.add_argument("--vpn" , "-n", help = "specify an existing vpn connection id (e.g. vpn-abcd1234)")
	parser.add_argument("--host" , "-d", help = "specify docker host API endpoint(optional)")
	args = parser.parse_args()
	
	if  len(sys.argv) <= 1  :
		parser.print_help()
	
	if args.vpn :
		peer_vpn(args.region , args.vpn, args.host)
		return

if __name__ == "__main__":
	main()
