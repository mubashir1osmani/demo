#!/bin/bash
# Verify the BGP Clos lab is working
# Usage: ./verify.sh

LAB_NAME="bgp-clos"
NODES=("leaf1" "leaf2" "spine1" "spine2")

run_cmd() {
  local node=$1
  shift
  docker exec clab-${LAB_NAME}-${node} vtysh -c "$*"
}

echo "============================================"
echo "  BGP Clos Lab Verification"
echo "============================================"

# 1. BGP session status
echo -e "\n--- BGP Neighbor Summary ---\n"
for node in "${NODES[@]}"; do
  echo "[$node]"
  run_cmd "$node" "show bgp summary"
  echo ""
done

# 2. Routing tables on leaves (should see each other's prefixes)
echo "--- Leaf Routing Tables (BGP routes) ---\n"
for node in leaf1 leaf2; do
  echo "[$node]"
  run_cmd "$node" "show ip route bgp"
  echo ""
done

# 3. ECMP verification — leaf1 should have 2 paths to leaf2's prefix
echo "--- ECMP Check: leaf1 -> 10.2.0.0/24 (should show 2 next-hops) ---\n"
run_cmd leaf1 "show ip route 10.2.0.0/24"

echo ""
echo "--- ECMP Check: leaf2 -> 10.1.0.0/24 (should show 2 next-hops) ---\n"
run_cmd leaf2 "show ip route 10.1.0.0/24"

# 4. End-to-end connectivity
echo ""
echo "--- Ping: leaf1 -> leaf2 loopback (10.0.0.2) ---"
docker exec clab-${LAB_NAME}-leaf1 ping -c 3 -W 1 10.0.0.2

echo ""
echo "--- Ping: leaf2 -> leaf1 loopback (10.0.0.1) ---"
docker exec clab-${LAB_NAME}-leaf2 ping -c 3 -W 1 10.0.0.1

echo ""
echo "============================================"
echo "  Verification Complete"
echo "============================================"
