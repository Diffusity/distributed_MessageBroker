#!/bin/bash
set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Distributed Message Broker — Demo              ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
echo ""

# ── Step 1: Start cluster ──
echo -e "${YELLOW}[1/6] Starting 3-broker cluster + PostgreSQL...${NC}"
docker-compose up -d --build
echo "Waiting 25 seconds for Spring Boot and leader election..."
sleep 25

# ── Step 2: Check leader ──
echo -e "${YELLOW}[2/6] Checking Raft leader election...${NC}"
for port in 8082 8083 8084; do
  STATE=$(curl -s http://localhost:$port/api/v1/raft/state 2>/dev/null || echo '{"error":"unreachable"}')
  echo "  broker @ :$port → $STATE"
done

# ── Step 3: Create topic ──
echo ""
echo -e "${YELLOW}[3/6] Creating topic 'orders' with 6 partitions...${NC}"
curl -s -X POST http://localhost:8082/api/v1/topics \
  -H "Content-Type: application/json" \
  -d '{"name":"orders","partitionCount":6}' | python -m json.tool 2>/dev/null || \
  curl -s -X POST http://localhost:8082/api/v1/topics \
  -H "Content-Type: application/json" \
  -d '{"name":"orders","partitionCount":6}'
echo ""

# ── Step 4: Produce messages ──
echo -e "${YELLOW}[4/6] Producing 10 messages with key-based routing...${NC}"
for i in $(seq 1 10); do
  RESPONSE=$(curl -s -X POST http://localhost:8082/api/v1/producer/produce \
    -H "Content-Type: application/json" \
    -d "{\"topicName\":\"orders\",\"key\":\"user-$i\",\"value\":\"order-payload-$i\"}")
  echo -e "  ${GREEN}✓${NC} Message $i → $RESPONSE"
done

# ── Step 5: Consume ──
echo ""
echo -e "${YELLOW}[5/6] Consuming from partition 0...${NC}"
curl -s "http://localhost:8082/api/v1/consumer/consume?topic=orders&group=demo-group&partition=0" | \
  python -m json.tool 2>/dev/null || \
  curl -s "http://localhost:8082/api/v1/consumer/consume?topic=orders&group=demo-group&partition=0"

# ── Step 6: Metrics ──
echo ""
echo -e "${YELLOW}[6/6] Cluster metrics...${NC}"
curl -s http://localhost:8082/api/v1/metrics/cluster | python -m json.tool 2>/dev/null || \
  curl -s http://localhost:8082/api/v1/metrics/cluster

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   Demo complete!                                 ║${NC}"
echo -e "${CYAN}║   Cluster running on ports 8082, 8083, 8084      ║${NC}"
echo -e "${CYAN}║   To stop: docker-compose down -v                ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════╝${NC}"
