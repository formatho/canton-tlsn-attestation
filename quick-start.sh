#!/bin/bash

# Canton TLSNotary Attestation - Quick Start Script
# This script automates the deployment and testing process

set -e

echo "🚀 Canton TLSNotary Attestation - Quick Start"
echo "============================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

# Check DAML SDK
if ! command -v daml &> /dev/null; then
    echo -e "${YELLOW}DAML SDK not found. Installing...${NC}"
    curl -sSL https://get.daml.com | sh
    export PATH="$HOME/.daml/bin:$PATH"
fi

# Check Canton
if ! command -v canton &> /dev/null; then
    echo -e "${YELLOW}Canton not found. Please install Canton manually.${NC}"
    echo "Visit: https://docs.daml.com/canton"
    exit 1
fi

# Check Rust (for TLSNotary)
if ! command -v cargo &> /dev/null; then
    echo -e "${YELLOW}Rust not found. Installing...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
    source $HOME/.cargo/env
fi

echo -e "${GREEN}✓ Prerequisites checked${NC}"

# Build DAML contracts
echo -e "${BLUE}Building DAML contracts...${NC}"
cd daml
daml build
echo -e "${GREEN}✓ DAML contracts built${NC}"

# Start Canton participant (background)
echo -e "${BLUE}Starting Canton participant...${NC}"
canton participant1 start --config canton.conf > /tmp/canton.log 2>&1 &
CANTON_PID=$!
sleep 5

# Check if Canton started
if ! kill -0 $CANTON_PID 2>/dev/null; then
    echo -e "${YELLOW}Failed to start Canton. Check /tmp/canton.log${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Canton participant started (PID: $CANTON_PID)${NC}"

# Upload DAML package
echo -e "${BLUE}Uploading DAML package to Canton...${NC}"
daml ledger upload participant1 \
  --package-file .daml/dist/canton-tlsn-attestation-1.0.0.dar
echo -e "${GREEN}✓ Package uploaded${NC}"

# Create Attestation Registry
echo -e "${BLUE}Creating Attestation Registry...${NC}"
REGISTRY_CID=$(canton participant1 ledger create \
  --template TLSNotaryAttestation:AttestationRegistry \
  --payload 'operator = "Operator", notaries = {}' \
  --output-file /tmp/registry-cid.txt \
  --contract-id)

echo -e "${GREEN}✓ Registry created${NC}"
echo "Registry CID: $REGISTRY_CID"

# Register Notary
echo -e "${BLUE}Registering trusted Notary...${NC}"
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

echo -e "${GREEN}✓ Notary registered${NC}"
echo "Notary CID: $NOTARY_CID"

# Run example flow
echo -e "${BLUE}Running example KYC flow...${NC}"
daml script --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar \
  --script-name TLSNotaryAttestation.Examples:exampleKYCFlow \
  --argument 'operator = "Operator", user = "Alice", institution = "Bank"'

echo -e "${GREEN}✓ Example flow completed${NC}"

# Start trigger (background)
echo -e "${BLUE}Starting automated verification trigger...${NC}"
daml trigger \
  --ledger-host localhost \
  --ledger-port 5011 \
  --party Operator \
  --trigger-name TLSNotaryAttestation:AttestationTrigger \
  --max-retries 10 > /tmp/trigger.log 2>&1 &
TRIGGER_PID=$!

echo -e "${GREEN}✓ Trigger started (PID: $TRIGGER_PID)${NC}"

# Display summary
echo ""
echo "============================================="
echo -e "${GREEN}🎉 Deployment successful!${NC}"
echo "============================================="
echo ""
echo "Running processes:"
echo "  - Canton participant: PID $CANTON_PID"
echo "  - Verification trigger: PID $TRIGGER_PID"
echo ""
echo "Contract IDs:"
echo "  - Registry CID: $(cat /tmp/registry-cid.txt)"
echo "  - Notary CID: $(cat /tmp/notary-cid.txt)"
echo ""
echo "Useful commands:"
echo "  - View Canton logs: tail -f /tmp/canton.log"
echo "  - View trigger logs: tail -f /tmp/trigger.log"
echo "  - Stop all: kill $CANTON_PID $TRIGGER_PID"
echo ""
echo "Next steps:"
echo "  1. Open Navigator: daml navigator"
echo "  2. Test with real TLSNotary attestations"
echo "  3. Integrate with your applications"
echo ""
echo "For more info, see:"
echo "  - README.md - Project overview"
echo "  - DEPLOYMENT_GUIDE.md - Full deployment guide"
echo ""

# Save PIDs for cleanup
echo $CANTON_PID > /tmp/canton.pid
echo $TRIGGER_PID >> /tmp/canton.pid

echo "PIDs saved to /tmp/canton.pid"
echo "Run 'kill \$(cat /tmp/canton.pid)' to stop all processes"
echo ""
echo -e "${GREEN}Done! 🚀${NC}"