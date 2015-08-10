#!/bin/bash

source ./net_env.sh

ha_qr_info=$(neutron port-list | grep \"${PROXY_SUBNET_GATEWAY_IP}\")
separator
if [[ $ha_qr_info =~ $mac_re ]]; then
    ha_qr_mac=${BASH_REMATCH}
    echo "Find mac address of proxy network gateway \"${ha_qr_mac}\""
else
    echo "Can't find mac address of proxy network gateway!"
    exit 1
fi
separator

ha_router_info=$(neutron router-list | grep ${R_ROUTER_PUBLIC})
if [[ $ha_router_info =~ $uuid_re ]]; then
    ha_router_uuid=${BASH_REMATCH}
    if [[ $ha_router_uuid =~ $uuid_re1 ]]; then
        ha_router_uuid=${BASH_REMATCH}
        echo "Find uuid of public ha router \"${ha_router_uuid}\""
    else
        echo "Can't find uuid of public ha router!"
        exit 1
    fi
else
    echo "Can't find uuid of public ha router!"
    exit 1
fi
separator

# Find which l3-agent hosts the active ha router.
active_l3_agent_host_router=$(neutron l3-agent-list-hosting-router ${R_ROUTER_PUBLIC} -c host -c ha_state | grep active)
active_l3_agent=${active_l3_agent_host_router#*|}
active_l3_agent=${active_l3_agent%%|*}
echo "Active instance of ${R_ROUTER_PUBLIC} is at ${active_l3_agent}"
separator

ha_qr_name_info=$(ssh ${active_l3_agent} "ip netns exec qrouter-${ha_router_uuid} ip a | grep ${PROXY_SUBNET_GATEWAY_IP}")
if [[ $ha_qr_name_info =~ $qr_re ]]; then
    ha_qr_name=${BASH_REMATCH}
    echo "Find name of qr device in ${R_ROUTER_PUBLIC} \"${ha_qr_name}\""
else
    echo "Can't find name of qr device in public ha router!"
    exit 1
fi
separator

dvr_router_info=$(neutron router-list | grep ${R_ROUTER_INTERNAL})
if [[ $dvr_router_info =~ $uuid_re ]]; then
    dvr_router_uuid=${BASH_REMATCH}
    if [[ $dvr_router_uuid =~ $uuid_re1 ]]; then
        dvr_router_uuid=${BASH_REMATCH}
        echo "Find uuid of ${R_ROUTER_INTERNAL} \"${dvr_router_uuid}\""
    else
        echo "Can't find uuid of ${R_ROUTER_INTERNAL}!"
        exit 1
    fi
else
    echo "Can't find uuid of ${R_ROUTER_INTERNAL}!"
    exit 1
fi
separator

proxy_qr_name_info=$(ip netns exec qrouter-${dvr_router_uuid} ip a | grep ${PROXY_PORT_ADDRESS})
if [[ $proxy_qr_name_info =~ $qr_re ]]; then
    proxy_qr_name=${BASH_REMATCH}
    echo "Find name of qr device of ${PROXY_PORT_ADDRESS} \"${proxy_qr_name}\""
else
    echo "Can't find name of qr device of ${PROXY_PORT_ADDRESS}!"
    exit 1
fi
separator

# Find out compute hostname, and neighbour table to it and delete ha router qr flow rule.
while read -r line;do
    compute_hostname=${line#*|}
    compute_hostname=${compute_hostname%%|*}
    echo "Find one compute node \"$compute_hostname\""
    separator

    # Add neighbour table to dvr router namespace.
    grep_result=$(ssh ${compute_hostname} "ip netns exec qrouter-$dvr_router_uuid ip n | grep '${PROXY_SUBNET_GATEWAY_IP} '" < /dev/null)
    if [ -z "$grep_result" ]; then
        ssh ${compute_hostname} "ip netns exec qrouter-$dvr_router_uuid ip n add ${PROXY_SUBNET_GATEWAY_IP} dev ${proxy_qr_name} lladdr ${ha_qr_mac}" < /dev/null
    else
        ssh ${compute_hostname} "ip netns exec qrouter-$dvr_router_uuid ip n chg ${PROXY_SUBNET_GATEWAY_IP} dev ${proxy_qr_name} lladdr ${ha_qr_mac}" < /dev/null
    fi
    if [ $? -ne 0 ]; then
      echo "Failed to add ${PROXY_SUBNET_GATEWAY_IP} neighbour table to ${R_ROUTER_INTERNAL} namespace on host ${compute_hostname}!"
      exit 1
    else
      echo "Add ${PROXY_SUBNET_GATEWAY_IP} neighbour table to ${R_ROUTER_INTERNAL} namespace on host ${compute_hostname}."
    fi
    separator

    # Del the flow rule about qr of ha router in br-tun table=20
    ha_qr_flow_info=$(ssh ${compute_hostname} "ovs-ofctl dump-flows br-tun table=20 | grep ${ha_qr_mac}" < /dev/null)
    if [[ $ha_qr_flow_info =~ $dlvlan_re ]]; then
        ha_qr_dlvlan=${BASH_REMATCH}
        ssh ${compute_hostname} "ovs-ofctl del-flows br-tun \"table=20, ${ha_qr_dlvlan},dl_dst=${ha_qr_mac}\"" < /dev/null
        echo "Find the flow rule about qr of ${R_ROUTER_PUBLIC} in br-tun of the host ${compute_hostname}, and delete it."
    else
        echo "Can't find the flow rule about qr of ${R_ROUTER_PUBLIC} in br-tun of the host ${compute_hostname}, do nothing"
    fi
    separator
done < <(nova host-list | grep compute)

# Find out controller hostname, add flow rule in br-int to point qr of ha router.
while read -r line;do
    controller_hostname=${line#*|}
    controller_hostname=${controller_hostname%%|*}
    echo "Find one controller node \"$controller_hostname\""
    separator

    # Add the flow rule about qr of ha router in br-int table=0
    # Find the port of patch-tun
    patch_tun_info=$(ssh ${controller_hostname} "ovs-ofctl show br-int | grep patch-tun" < /dev/null)
    if [[ $patch_tun_info =~ $port_num_re ]]; then
        patch_tun_num=${BASH_REMATCH}
        patch_tun_num=${patch_tun_num%(*}
    fi
    # Find the port of ha router qr
    ha_port_info=$(ssh ${controller_hostname} "ovs-ofctl show br-int | grep ${ha_qr_name}" < /dev/null)
    if [[ $ha_port_info =~ $port_num_re ]]; then
        ha_port_num=${BASH_REMATCH}
        ha_port_num=${ha_port_num%(*}
    fi
    ssh ${controller_hostname} "ovs-ofctl add-flow br-int \"table=0,priority=4,in_port=${patch_tun_num},dl_dst=${ha_qr_mac},actions=strip_vlan,output:${ha_port_num}\"" < /dev/null
    if [ $? -ne 0 ]; then
      echo "Failed to add flow rule in br-int to flow qr of ${R_ROUTER_PUBLIC} host ${controller_hostname}!"
      exit 1
    else
      echo "Add flow rule in br-int to flow qr of ${R_ROUTER_PUBLIC} host ${controller_hostname}."
    fi
    separator
done < <(neutron l3-agent-list-hosting-router ${R_ROUTER_PUBLIC} -c host  -c alive | grep ':-)')

