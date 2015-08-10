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

yellow_vip_port_info=$(neutron port-list | grep \"${YELLOW_VIP_ADDRESS}\")
if [[ $yellow_vip_port_info =~ $mac_re ]]; then
    yellow_vip_mac=${BASH_REMATCH}
    echo "Find mac address of yellow vip \"${yellow_vip_mac}\""
else
    echo "Can't find mac address of yellow vip!"
    exit 1
fi
separator

yellow_pool_info=$(neutron lb-pool-list | grep ${YELLOW_LB_NAME})
if [[ $yellow_pool_info =~ $uuid_re ]]; then
    yellow_pool_uuid=${BASH_REMATCH}
    if [[ $yellow_pool_uuid =~ $uuid_re1 ]]; then
        yellow_pool_uuid=${BASH_REMATCH}
        echo "Find uuid of yellow lb pool \"${yellow_pool_uuid}\""
    else
        echo "Can't find uuid of yellow lb pool!"
        exit 1
    fi
else
    echo "Can't find uuid of yellow lb pool!"
    exit 1
fi
separator

# Find which lbaas-agent hosts the lb pool.
lbaas_agent_host_pool=$(neutron lb-agent-hosting-pool ${YELLOW_LB_NAME} -c host)
lbaas_agent=${lbaas_agent_host_pool%|*}
lbaas_agent=${lbaas_agent##*|}
echo "Load balancer ${YELLOW_LB_NAME} is at ${lbaas_agent}"
separator

vip_tap_name_info=$(ssh ${lbaas_agent} "ip netns exec qlbaas-${yellow_pool_uuid} ip a | grep ${YELLOW_VIP_ADDRESS}")
if [[ $vip_tap_name_info =~ $tap_re ]]; then
    yellow_vip_tap_name=${BASH_REMATCH}
    echo "Find name of tap device of ${YELLOW_LB_NAME} \"${yellow_vip_tap_name}\""
else
    echo "Can't find name of tap device of ${YELLOW_LB_NAME}!"
    exit 1
fi
separator

# Add neighbour table to ha router namespace.
grep_result=$(ssh ${active_l3_agent} "ip netns exec qrouter-$ha_router_uuid ip n | grep '${YELLOW_VIP_ADDRESS} '")
if [ -z "$grep_result" ]; then
    ssh ${active_l3_agent} "ip netns exec qrouter-$ha_router_uuid ip n add ${YELLOW_VIP_ADDRESS} dev ${ha_qr_name} lladdr ${yellow_vip_mac}"
else
    ssh ${active_l3_agent} "ip netns exec qrouter-$ha_router_uuid ip n chg ${YELLOW_VIP_ADDRESS} dev ${ha_qr_name} lladdr ${yellow_vip_mac}"
fi
if [ $? -ne 0 ]; then
  echo "Failed to add ${YELLOW_VIP_NAME} neighbour table to ${R_ROUTER_PUBLIC} namespace."
  exit 1
else
  echo "Add ${YELLOW_VIP_NAME} neighbour table to ${R_ROUTER_PUBLIC} namespace."
fi
separator

# Add neighbour table to lbaas namespace.
grep_result=$(ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip n | grep '${PROXY_SUBNET_GATEWAY_IP} '")
if [ -z "$grep_result" ]; then
    ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip n add ${PROXY_SUBNET_GATEWAY_IP} dev ${yellow_vip_tap_name} lladdr ${ha_qr_mac}"
else
    ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip n chg ${PROXY_SUBNET_GATEWAY_IP} dev ${yellow_vip_tap_name} lladdr ${ha_qr_mac}"
fi
if [ $? -ne 0 ]; then
  echo "Failed to add ${PROXY_NET_NAME} gateway neighbour table to ${YELLOW_LB_NAME} namespace."
  exit 1
else
  echo "Add ${PROXY_NET_NAME} gateway neighbour table to ${YELLOW_LB_NAME} namespace."
fi
separator

# Add route to lbaas namespace for tenant networks.
grep_result=$(ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip r | grep ${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR}")
if [ -z "$grep_result" ]; then
    ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip r add ${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR} via ${PROXY_PORT_ADDRESS} dev ${yellow_vip_tap_name}"
    if [ $? -ne 0 ]; then
      echo "Fail to add ${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR} to ${YELLOW_LB_NAME}'s route table!"
      exit 1
    else
      echo "Add ${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR} to ${YELLOW_LB_NAME}'s route table."
    fi
else
    echo "${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR} is at ${YELLOW_LB_NAME}'s route table now, do nothing."
fi
separator

grep_result=$(ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip r | grep ${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR}")
if [ -z "$grep_result" ]; then
    ssh ${lbaas_agent} "ip netns exec qlbaas-$yellow_pool_uuid ip r add ${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR} via ${PROXY_PORT_ADDRESS} dev ${yellow_vip_tap_name}"
    if [ $? -ne 0 ]; then
      echo "Fail to add ${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR} to ${YELLOW_LB_NAME}'s route table!"
      exit 1
    else
      echo "Add ${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR} to ${YELLOW_LB_NAME}'s route table."
    fi
else
    echo "${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR} is at ${YELLOW_LB_NAME}'s route table now, do nothing."
fi
separator

# Del the flow rule about qr of ha router in br-tun table=20
ha_qr_flow_info=$(ssh ${lbaas_agent} "ovs-ofctl dump-flows br-tun table=20 | grep ${ha_qr_mac}")
if [[ $ha_qr_flow_info =~ $dlvlan_re ]]; then
    ha_qr_dlvlan=${BASH_REMATCH}
    ssh ${lbaas_agent} "ovs-ofctl del-flows br-tun \"table=20, ${ha_qr_dlvlan},dl_dst=${ha_qr_mac}\""
    echo "Find the flow rule about qr of ${R_ROUTER_PUBLIC} in br-tun of the host of lbaas, and delete it."
else
    echo "Can't find the flow rule about qr of ${R_ROUTER_PUBLIC} in br-tun of the host of lbaas, do nothing"
fi
separator
