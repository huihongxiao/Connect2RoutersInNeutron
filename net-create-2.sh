#!/bin/bash

source ./net_env.sh


neutron net-create ${AZ1_YELLOW_NET_NAME} \
  --provider:network_type vxlan \
  --provider:segmentation_id ${AZ1_YELLOW_NET_SEGID} \
  --tenant-id ${PROJECT_ID}

neutron net-create ${AZ2_YELLOW_NET_NAME} \
  --provider:network_type vxlan \
  --provider:segmentation_id ${AZ2_YELLOW_NET_SEGID} \
  --tenant-id ${PROJECT_ID}

neutron net-create ${AZ1_RED_NET_NAME} \
  --provider:network_type vxlan \
  --provider:segmentation_id ${AZ1_RED_NET_SEGID} \
  --tenant-id ${PROJECT_ID}

neutron net-create ${AZ2_RED_NET_NAME} \
  --provider:network_type vxlan \
  --provider:segmentation_id ${AZ2_RED_NET_SEGID} \
  --tenant-id ${PROJECT_ID}

neutron net-create ${PUBLIC_NET_NAME} \
  --provider:network_type ${PUBLIC_NET_TYPE}  \
  --provider:physical_network ${PUBLIC_NET_PHYSNET} \
  --tenant-id ${PROJECT_ID} \
  --router:external \
  --shared


neutron subnet-create  ${AZ1_YELLOW_NET_NAME} \
                             --tenant-id  ${PROJECT_ID} \
                             --name "${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR}" \
                             --gateway ${AZ1_YELLOW_SUBNET_GATEWAY_IP} \
                             --allocation-pool start=${AZ1_YELLOW_SUBNET_ALLOCATION_POOL_START},end=${AZ1_YELLOW_SUBNET_ALLOCATION_POOL_END} \
                             --dns-nameserver ${AZ1_YELLOW_SUBNET_DNS} \
                             --enable-dhcp \
                             --ip-version ${AZ1_YELLOW_IP_VERSIONS} \
                             ${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR} 

neutron subnet-create  ${AZ2_YELLOW_NET_NAME} \
                             --tenant-id  ${PROJECT_ID} \
                             --name "${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR}" \
                             --gateway ${AZ2_YELLOW_SUBNET_GATEWAY_IP} \
                             --allocation-pool start=${AZ2_YELLOW_SUBNET_ALLOCATION_POOL_START},end=${AZ2_YELLOW_SUBNET_ALLOCATION_POOL_END} \
                             --dns-nameserver ${AZ2_YELLOW_SUBNET_DNS} \
                             --enable-dhcp \
                             --ip-version ${AZ2_YELLOW_IP_VERSIONS} \
                             ${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR}





neutron subnet-create  ${AZ1_RED_NET_NAME} \
                             --tenant-id  ${PROJECT_ID} \
                             --name "${AZ1_RED_SUBNET_NETWORK}/${AZ1_RED_SUBNET_CIDR}" \
                             --gateway ${AZ1_RED_SUBNET_GATEWAY_IP} \
                             --allocation-pool start=${AZ1_RED_SUBNET_ALLOCATION_POOL_START},end=${AZ1_RED_SUBNET_ALLOCATION_POOL_END} \
                             --dns-nameserver ${AZ1_RED_SUBNET_DNS} \
                             --enable-dhcp \
                             --ip-version ${AZ1_RED_IP_VERSIONS} \
                             ${AZ1_RED_SUBNET_NETWORK}/${AZ1_RED_SUBNET_CIDR}

neutron subnet-create  ${AZ2_RED_NET_NAME} \
                             --tenant-id  ${PROJECT_ID} \
                             --name "${AZ2_RED_SUBNET_NETWORK}/${AZ2_RED_SUBNET_CIDR}" \
                             --gateway ${AZ2_RED_SUBNET_GATEWAY_IP} \
                             --allocation-pool start=${AZ2_RED_SUBNET_ALLOCATION_POOL_START},end=${AZ2_RED_SUBNET_ALLOCATION_POOL_END} \
			     --dns-nameserver ${AZ2_RED_SUBNET_DNS} \
                             --enable-dhcp \
                             --ip-version ${AZ2_RED_IP_VERSIONS} \
                             ${AZ2_RED_SUBNET_NETWORK}/${AZ2_RED_SUBNET_CIDR}

neutron subnet-create  ${PUBLIC_NET_NAME} \
                             --tenant-id  ${PROJECT_ID} \
                             --name "${PUBLIC_SUBNET_NETWORK}/${PUBLIC_SUBNET_CIDR}" \
                             --gateway ${PUBLIC_SUBNET_GATEWAY_IP} \
                             --allocation-pool "${PUBLIC_SUBNET_ALLOCATION_POOL}" \
                             --dns-nameserver ${PUBLIC_SUBNET_DNS} \
			     --enable-dhcp=${PUBLIC_SUBNET_ENABLE_DHCP} \
                             --ip-version ${PUBLIC_IP_VERSIONS} \
                             ${PUBLIC_SUBNET_NETWORK}/${PUBLIC_SUBNET_CIDR}


neutron lb-pool-create --lb-method ${RED_LB_METHOD} \
                       --name ${RED_LB_NAME} --protocol TCP \
                       --subnet-id ${RED_LB_SUBNET} \
                       --tenant-id ${PROJECT_ID}

neutron lb-vip-create --name ${RED_VIP_NAME} \
                      --protocol-port ${RED_VIP_PROTOCOL_PORT} --protocol TCP \
                      --subnet-id  ${RED_VIP_SUBNET} \
                      --address ${RED_VIP_ADDRESS} \
                      ${RED_LB_NAME}


neutron router-create ${R_ROUTER_INTERNAL} \
  --distributed True \
  --ha False \
  --tenant-id ${PROJECT_ID}

neutron router-interface-add ${R_ROUTER_INTERNAL}  "subnet=${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR}"
neutron router-interface-add ${R_ROUTER_INTERNAL}  "subnet=${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR}"
neutron router-interface-add ${R_ROUTER_INTERNAL}  "subnet=${AZ1_RED_SUBNET_NETWORK}/${AZ2_RED_SUBNET_CIDR}"
neutron router-interface-add ${R_ROUTER_INTERNAL}  "subnet=${AZ2_RED_SUBNET_NETWORK}/${AZ2_RED_SUBNET_CIDR}"



neutron net-create ${PROXY_NET_NAME} \
  --provider:network_type vxlan \
  --provider:segmentation_id ${PROXY_NET_SEGID} \
  --tenant-id ${PROJECT_ID}


neutron subnet-create  ${PROXY_NET_NAME} \
                             --tenant-id  ${PROJECT_ID} \
                             --name "${PROXY_SUBNET_NETWORK}/${PROXY_SUBNET_CIDR}" \
                             --gateway ${PROXY_SUBNET_GATEWAY_IP} \
                             --allocation-pool start=${PROXY_SUBNET_ALLOCATION_POOL_START},end=${PROXY_SUBNET_ALLOCATION_POOL_END} \
                             --dns-nameserver ${PROXY_SUBNET_DNS} \
                             --enable-dhcp \
                             --ip-version ${PROXY_SUBNET_IP_VERSIONS} \
                             ${PROXY_SUBNET_NETWORK}/${PROXY_SUBNET_CIDR}


neutron port-create --name ${PROXY_PORT_NAME} --fixed-ip ip_address=${PROXY_PORT_ADDRESS} ${PROXY_NET_NAME}


neutron lb-pool-create --lb-method ${YELLOW_LB_METHOD} \
                       --name ${YELLOW_LB_NAME} --protocol TCP \
                       --subnet-id "${PROXY_SUBNET_NETWORK}/${PROXY_SUBNET_CIDR}" \
                       --tenant-id ${PROJECT_ID}

neutron lb-vip-create --name ${YELLOW_VIP_NAME} \
                      --protocol-port ${YELLOW_VIP_PROTOCOL_PORT} --protocol TCP \
                      --subnet-id  "${PROXY_SUBNET_NETWORK}/${PROXY_SUBNET_CIDR}" \
                      --address ${YELLOW_VIP_ADDRESS} \
                      ${YELLOW_LB_NAME}

neutron router-create ${R_ROUTER_PUBLIC} \
  --distributed False \
  --ha True \
  --tenant-id ${PROJECT_ID}

neutron router-interface-add ${R_ROUTER_PUBLIC}  "subnet=${PROXY_SUBNET_NETWORK}/${PROXY_SUBNET_CIDR}"
neutron router-gateway-set ${R_ROUTER_PUBLIC}  ${PUBLIC_NET_NAME} 

neutron router-interface-add ${R_ROUTER_INTERNAL}  "port=${PROXY_PORT_NAME}"

neutron router-update ${R_ROUTER_PUBLIC} --routes type=dict list=true destination=${AZ1_RED_SUBNET_NETWORK}/${AZ1_RED_SUBNET_CIDR},nexthop=${PROXY_PORT_ADDRESS} \
                                                                      destination=${AZ2_RED_SUBNET_NETWORK}/${AZ2_RED_SUBNET_CIDR},nexthop=${PROXY_PORT_ADDRESS} \
                                                                      destination=${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR},nexthop=${PROXY_PORT_ADDRESS} \
                                                                      destination=${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_TELLOW_SUBNET_CIDR},nexthop=${PROXY_PORT_ADDRESS}

neutron router-update ${R_ROUTER_INTERNAL} --routes type=dict list=true destination=0.0.0.0/0,nexthop=${PROXY_SUBNET_GATEWAY_IP}

neutron floatingip-create  ${PUBLIC_NET_NAME} 
neutron floatingip-create  ${PUBLIC_NET_NAME}  

