# Transit VPC for AWS

Use docker to deliver a transit vpc soltuion for AWS

##1. Prepare ( if you are running this on EC2 )
a) select a proper region,Create a seperate VPC as transit VPC , with 2 public subnets, and configure Security Groups according to your need;

b) Create an IAM role for the instances , with describe-vpn-connections permission.

c) Launch an EC2 instances in each subnets, using Amazon Linux AMI (tested, other distribution should also work, but untested at this time) , remember to assign above roles to instance

d) Associate EIPs to above instances, if needed

UserData:
```
	#!/bin/sh
	yum update && yum -y install docker
```

If you are running this on somewhere else, then you may need to either configure proper access credentials for the helper script ( peer.py ) or you may simply pass every required parameters through environment varaiables during the launch of container.


##2 How to peer with other VPC

with the helper script peer.py 
a) Create Customer Gateway in target region, using EIP address of above instances, Dynamic Routing , choose your own ASN, (e.g. 65000)

b) Create & attach VGW to target VPC(s) in target regions(s) , remeber to enable VGW's route propergation;

c) Create VPN connection(s) between CGW and VGW, note the connection ID  (vpn-abcdef12)

d) SSH to the corresponding instance, and call peer.py -r TARGET_REGION -n vpn-abcdef12 

e) wait for the VPN connection to be up & running

f) repeat steps a-e to interconnection each and every target VPC(s) in target region(s) 

Or by 

```
	cat <<EOF > tunnelcfg
VGW1=1.2.3.4
PSK1=psk1
VTI1_LOCAL=169.254.0.1
VTI1_REMOT=169.254.0.2
VGW2=1.2.3.5
PSK2=psk2
VTI2_LOCAL=169.254.0.5
VTI2_REMOT=169.254.0.6
LOCAL_ASN=65001
REMOTE_ASN=7224
EOF

	docker run --privileged -d --env_file tunnelcfg chandlerding/aws-cgw 
	
	or if you want it to run on host network
	docker run --privileged --net=host -d --env_file tunnelcfg chandlerding/aws-cgw 
	
```

##3 How to enable routing between interconnected VPCs

a) Create a BIRD container, the configuration of the routing daemon allows it act as a Route Refelector.
```
	docker run --privileged --net=host --name bird chandlerding/bird 
```
b) Neighboring with each vpn-xxxxxxxx container, so they can learn each others' route  
```
docker exec bird bird.sh add NEIGHBOR_IP ASN
```

##More automation coming.
