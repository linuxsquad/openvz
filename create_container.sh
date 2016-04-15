#!/bin/bash
#
# DESCRIPTION: This script automates creation of openvz container on the host
#
# PRE-REQUISIT: Host has to be configured as OpenVZ host, and atleast has Ubuntu,
#               CentOS 7 and Scientific 6 OS templates. In addition, bridge network interface
#               should be set up.
#
# INPUT:        Script is interractive and does not take command line input
#
# OUTPUT:       starts new CT and add its virtual NIC to the host bridge interface
#               Ubuntu: repos are updated, and OS is upgraded
#               Ubuntu: puppet is installed
#
# RELEASE NOTE:
#

typeset DOMAIN_NAME="example.com"
typeset SWAP="1G"

echo " == Createing a new container"
echo " == Currently configured CT on this server:"
vzlist -a -o ctid,hostname,ostemplate,diskspace,status -s ctid
last_ctid=`vzlist -a -o ctid -s ctid | tail -n1 | sed -e 's/^\ *//'`
new_ctid=$(( ${last_ctid} + 1 ))
new_hostname="vm${new_ctid}.${DOMAIN_NAME}"
echo " == Proposed Container Name: "$new_hostname", and CT ID:"$new_ctid
echo " == Please answer the following questions:"
while true; do
    read -p " === 1- What OS? [D]ebian-8, [C]entOS-7, [S]cientific-6 " select_os
    case $select_os in
        [Ss] ) ostemplate="scientific-6-x86_64"
            break;;
        [Dd] ) ostemplate="debian-8.0-x86_64"
            break;;
        [Cc] ) ostemplate="centos-7-x86_64"
            break;;
        * ) echo " ERR: Unknown selection"
    esac
done

read -p " === 2- How much storage (soft limit, hard limit is extra 25%)? [5/10]GB " select_storage
new_storage=${select_storage:-5}"G:"$(( 5 * ${select_storage:-8} / 4 ))"G"

read -p " === 3- How much RAM? [1]GB " select_ram
new_ram=${select_ram:-1}"G"


  vzctl create $new_ctid  --ostemplate ${ostemplate} --config vswap-1g; wait
  vzctl set $new_ctid --hostname $new_hostname --save;  wait
  vzctl set $new_ctid --onboot yes --save;  wait
  vzctl set $new_ctid --ipdel all --save; wait
  vzctl set $new_ctid --netif_add eth0,,,,vmbr0 --save;  wait
#  vzctl set $new_ctid --physpages 0:unlimited --save;  wait
  vzctl set $new_ctid --cpus 4 --save;  wait
  vzctl set $new_ctid --ram $new_ram --save
  vzctl set $new_ctid --swap 1G --save
  vzctl set $new_ctid --diskspace $new_storage --save; wait
  sleep 5
  vzctl start $new_ctid; wait
  sleep 5
  vzctl set $new_ctid --reset_ub

echo " === 4- Configuring network interface ..."
if [ ${ostemplate} == "debian-8.0-x86_64" ]
then
    vzctl exec $new_ctid "echo -e '\n\nauto eth0' >> /etc/network/interfaces"; wait
    vzctl exec $new_ctid "echo -e '  iface eth0 inet dhcp\n' >> /etc/network/interfaces"; wait
    vzctl exec $new_ctid "service networking restart"; wait
    vzctl exec $new_ctid "apt-get clean"; wait
    vzctl exec $new_ctid "apt-get update"; wait
    vzctl exec $new_ctid "apt-get upgrade"; wait
    vzctl exec $new_ctid "apt-get install puppet"; wait
    vzctl exec $new_ctid "service bind9 stop"; wait
    vzctl exec $new_ctid "service apache2 stop"; wait
    vzctl exec $new_ctid "update-rc.d bind9 disable"; wait
    vzctl exec $new_ctid "update-rc.d apache2 disable"; wait
elif [ ${ostemplate} == "scientific-6-x86_64" ] ||
    [ ${ostemplate} == "centos-7-x86_64" ]
then
    vzctl exec $new_ctid "echo 'DEVICE=\"eth0\"' >> /etc/sysconfig/network-scripts/ifcfg-eth0"; wait
    vzctl exec $new_ctid "echo 'BOOTPROTO=\"dhcp\"' >> /etc/sysconfig/network-scripts/ifcfg-eth0"; wait
    vzctl exec $new_ctid "echo 'NM_CONTROLLED=\"no\"' >> /etc/sysconfig/network-scripts/ifcfg-eth0"; wait
    vzctl exec $new_ctid "echo 'ONBOOT=\"yes\"' >> /etc/sysconfig/network-scripts/ifcfg-eth0"; wait
    vzctl exec $new_ctid "echo 'TYPE=\"Ethernet\"' >> /etc/sysconfig/network-scripts/ifcfg-eth0"; wait
else
    echo " === ERR: Failed to add eth0: Uknown OS type"
    exit
fi

echo " ==== MAC for VM's network interface: "
echo "    " `vzctl exec $new_ctid ip a sh | grep -A2 eth | awk '/ether/ { print $2}'`
