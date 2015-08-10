#!/bin/bash

source ./net_env.sh
source ~/openrc

neutron lb-vip-delete ${RED_VIP_NAME}

neutron lb-vip-delete ${YELLOW_VIP_NAME}

neutron lb-pool-delete ${RED_LB_NAME}

neutron lb-pool-delete ${YELLOW_LB_NAME}


neutron router-update ${R_ROUTER_INTERNAL} --routes action=clear

neutron  router-interface-delete ${R_ROUTER_INTERNAL} "subnet=${AZ1_YELLOW_SUBNET_NETWORK}/${AZ1_YELLOW_SUBNET_CIDR}"
neutron  router-interface-delete ${R_ROUTER_INTERNAL} "subnet=${AZ2_YELLOW_SUBNET_NETWORK}/${AZ2_YELLOW_SUBNET_CIDR}"
neutron  router-interface-delete ${R_ROUTER_INTERNAL} "subnet=${AZ1_RED_SUBNET_NETWORK}/${AZ1_RED_SUBNET_CIDR}"
neutron  router-interface-delete ${R_ROUTER_INTERNAL} "subnet=${AZ2_RED_SUBNET_NETWORK}/${AZ2_RED_SUBNET_CIDR}"
neutron  router-interface-delete ${R_ROUTER_INTERNAL} "port=${PROXY_PORT_NAME}"

neutron router-update ${R_ROUTER_PUBLIC} --routes action=clear
neutron  router-interface-delete ${R_ROUTER_PUBLIC}  "subnet=${PROXY_SUBNET_NETWORK}/${PROXY_SUBNET_CIDR}"
neutron  router-gateway-clear ${R_ROUTER_PUBLIC}


neutron net-delete ${PUBLIC_NET_NAME}  \
  --tenant-id ${PROJECT_ID}


neutron net-delete ${AZ1_YELLOW_NET_NAME} \
  --tenant-id ${PROJECT_ID}

neutron net-delete ${AZ2_YELLOW_NET_NAME} \
  --tenant-id ${PROJECT_ID}


neutron net-delete ${AZ1_RED_NET_NAME} \
  --tenant-id ${PROJECT_ID}

neutron net-delete ${AZ2_RED_NET_NAME} \
  --tenant-id ${PROJECT_ID}

neutron net-delete ${PROXY_NET_NAME} \
  --tenant-id ${PROJECT_ID}

neutron router-delete ${R_ROUTER_PUBLIC} \
  --tenant-id ${PROJECT_ID}

neutron router-delete ${R_ROUTER_INTERNAL} \
  --tenant-id ${PROJECT_ID}

