#!/bin/bash

# Quick deployment script for local Canton development environment

set -e

echo "🚀 Quick Deployment to Local Canton"
echo "===================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}Step 1: Start Canton participant${NC}"
echo "-------------------------------------"

# Kill any existing Canton processes
pkill -f "canton.*participant1" 2>/dev/null || true

# Start Canton participant (in-memory for quick start)
canton participant1 start \
  --ledger-api-address "0.0.0.0" \
  --ledger-api-port 5011 \
  --admin-api-address "0.0.0.0" \
  --admin-api-port 5012 > /tmp/canton.log 2>&1 &

CANTON_PID=$!
echo "Canton started (PID: $CANTON_PID)"
echo "Logs: /tmp/canton.log"

# Wait for Canton to start
sleep 5

echo -e "${GREEN}✓ Canton participant started${NC}"

echo ""
echo -e "${BLUE}Step 2: Build DAML package${NC}"
echo "-------------------------------------"

cd daml
daml build

echo -e "${GREEN}✓ DAML package built${NC}"

echo ""
echo -e "${BLUE}Step 3: Upload to Canton${NC}"
echo "-------------------------------------"

daml ledger upload participant1 \
  --package-file .daml/dist/canton-tlsn-attestation-1.0.0.dar

echo -e "${GREEN}✓ Package uploaded${NC}"

echo ""
echo -e "${BLUE}Step 4: Create AttestationRegistry${NC}"
echo "-------------------------------------"

REGISTRY_CID=$(canton participant1 ledger create \
  --template TLSNotaryAttestation:AttestationRegistry \
  --payload 'operator = "Operator", notaries = {}' \
  --output-file /tmp/registry-cid.txt \
  --contract-id)

echo -e "${GREEN}✓ AttestationRegistry created${NC}"
echo "Contract ID: $REGISTRY_CID"

echo ""
echo -e "${BLUE}Step 5: Register TLSNotary notary${NC}"
echo "-------------------------------------"

NOTARY_CID=$(canton participant1 ledger.exercise \
  --contract-id $(cat /tmp/registry-cid.txt) \
  --choice RegisterNotary \
  --payload '{
    notaryId = "tlsnotary-official",
    publicKey = "031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f",
    name = "TLSNotary Official Notary Service",
    expiresAt = null
  }' \
  --output-file /tmp/notary-cid.txt \
  --contract-id)

echo -e "${GREEN}✓ TLSNotary notary registered${NC}"
echo "Contract ID: $NOTARY_CID"

echo ""
echo -e "${BLUE}Step 6: Run example flow${NC}"
echo "-------------------------------------"

daml script --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar \
  --script-name TLSNotaryAttestation.Examples:exampleKYCFlow \
  --argument 'operator = "Operator", user = "Alice", institution = "Bank"'

echo -e "${GREEN}✓ Example flow completed${NC}"

echo ""
echo "===================================="
echo -e "${GREEN}✅ Quick Deployment Complete!${NC}"
echo "===================================="
echo ""
echo "Running Services:"
echo "  - Canton participant: PID $CANTON_PID"
echo ""
echo "Contract IDs:"
echo "  - Registry: $REGISTRY_CID"
echo "  - Notary: $NOTARY_CID"
echo ""
echo "Next Steps:"
echo "  1. Start Navigator: daml navigator"
echo "  2. View contracts in browser"
echo "  3. Create attestations and KYC verifications"
echo ""
echo "Stop Canton:"
echo "  kill $CANTON_PID"
echo ""
echo -e "${GREEN}Deployed to local Canton! 🚀${NC}"

# Save PID for cleanup
echo $CANTON_PID > /tmp/canton.pid