#!/bin/bash

# Deploy Canton TLSNotary Attestation to Canton Network
# Production deployment script

set -e

echo "🚀 Deploying to Canton Network"
echo "==============================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
CANTON_PARTICIPANT="${CANTON_PARTICIPANT:-participant1}"
CANTON_DOMAIN="${CANTON_DOMAIN:-mydomain}"
CANTON_PORT="${CANTON_PORT:-5011}"

echo -e "${BLUE}Step 1: Build DAML package${NC}"
echo "-----------------------------------"

cd daml
daml build

echo -e "${GREEN}✓ DAML package built${NC}"

echo ""
echo -e "${BLUE}Step 2: Check Canton participant status${NC}"
echo "-----------------------------------"

if ! command -v canton &> /dev/null; then
    echo -e "${YELLOW}Canton CLI not found. Please install Canton first.${NC}"
    echo "Visit: https://docs.daml.com/canton"
    exit 1
fi

# Check if participant is running
canton $CANTON_PARTICIPANT health

echo -e "${GREEN}✓ Canton participant is running${NC}"

echo ""
echo -e "${BLUE}Step 3: Upload DAML package to Canton${NC}"
echo "-----------------------------------"

daml ledger upload $CANTON_PARTICIPANT \
  --package-file .daml/dist/canton-tlsn-attestation-1.0.0.dar

echo -e "${GREEN}✓ Package uploaded${NC}"

echo ""
echo -e "${BLUE}Step 4: Create AttestationRegistry${NC}"
echo "-----------------------------------"

# Create operator party
echo "Creating AttestationRegistry with operator: Operator"

REGISTRY_CID=$(canton $CANTON_PARTICIPANT ledger create \
  --template TLSNotaryAttestation:AttestationRegistry \
  --payload 'operator = "Operator", notaries = {}' \
  --output-file /tmp/registry-cid.txt \
  --contract-id)

echo -e "${GREEN}✓ AttestationRegistry created${NC}"
echo "Contract ID: $REGISTRY_CID"
echo "Saved to: /tmp/registry-cid.txt"

echo ""
echo -e "${BLUE}Step 5: Register TLSNotary Official Notary${NC}"
echo "-----------------------------------"

NOTARY_CID=$(canton $CANTON_PARTICIPANT ledger.exercise \
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

echo -e "${GREEN}✓ TLSNotary Official Notary registered${NC}"
echo "Contract ID: $NOTARY_CID"
echo "Saved to: /tmp/notary-cid.txt"

echo ""
echo -e "${BLUE}Step 6: Verify deployment${NC}"
echo "-----------------------------------"

# List packages
echo "Deployed packages:"
daml ledger list-participant-packages $CANTON_PARTICIPANT

echo ""
echo "Registered notaries:"
canton $CANTON_PARTICIPANT ledger list \
  --template TLSNotaryAttestation:NotaryInfo

echo ""
echo -e "${BLUE}Step 7: Setup automated verification trigger${NC}"
echo "-----------------------------------"

echo "Starting verification trigger (background)..."
daml trigger \
  --ledger-host localhost \
  --ledger-port $CANTON_PORT \
  --party Operator \
  --trigger-name TLSNotaryAttestation:AttestationTrigger \
  --max-retries 10 > /tmp/trigger.log 2>&1 &

TRIGGER_PID=$!
echo "Trigger started (PID: $TRIGGER_PID)"
echo "Logs: /tmp/trigger.log"

echo $TRIGGER_PID > /tmp/trigger.pid

echo ""
echo "=============================================="
echo -e "${GREEN}✅ Deployment Complete!${NC}"
echo "=============================================="
echo ""
echo "Deployed Components:"
echo "  - AttestationRegistry: $REGISTRY_CID"
echo "  - TLSNotary Official Notary: $NOTARY_CID"
echo "  - Verification Trigger: PID $TRIGGER_PID"
echo ""
echo "Next Steps:"
echo "  1. Create users and attestations"
echo "  2. Create KYC verifications for institutions"
echo "  3. Monitor verification trigger logs"
echo ""
echo "Useful Commands:"
echo "  - View trigger logs: tail -f /tmp/trigger.log"
echo "  - Stop trigger: kill \$(cat /tmp/trigger.pid)"
echo "  - List contracts: canton $CANTON_PARTICIPANT ledger list"
echo ""
echo "Documentation:"
echo "  - README.md - Quick start guide"
echo "  - DEPLOYMENT_GUIDE.md - Full deployment documentation"
echo "  - INTEGRATION_GUIDE.md - TLSNotary integration"
echo ""
echo -e "${GREEN}Deployed to Canton Network! 🚀${NC}"