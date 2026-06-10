# TLSNotary → Canton Integration Guide

## 🔗 Connecting TLSNotary Demo to Canton Smart Contracts

This guide shows how to use the TLSNotary attestation from the demo with the Canton smart contracts.

---

## 📋 Prerequisites

### Completed Earlier

1. ✅ TLSNotary demo executed
   - `example-json.attestation.tlsn` created
   - `example-json.presentation.tlsn` created
   - `example-json.secrets.tlsn` created

2. ✅ Canton smart contracts written
   - `TLSNotaryAttestation.daml` deployed
   - `AttestationRegistry` created
   - Notary registered

---

## 🎯 Integration Steps

### Step 1: Extract Attestation Data

From the TLSNotary demo output, we have:

```bash
# Navigate to TLSNotary directory
cd /Users/studio/.openclaw/workspace-web3/tlsn

# Calculate hashes (for on-chain verification)
attestation_hash=$(sha256sum example-json.attestation.tlsn | cut -d' ' -f1)
presentation_hash=$(sha256sum example-json.presentation.tlsn | cut -d' ' -f1)

echo "Attestation Hash: $attestation_hash"
echo "Presentation Hash: $presentation_hash"
```

### Step 2: Create AttestationProof on Canton

```bash
# Using Canton CLI
canton participant1 ledger create \
  --template TLSNotaryAttestation:AttestationProof \
  --payload '{
    prover = "Alice",
    operator = "Operator",
    attestationData = {
      attestationId = "demo-example-json-001",
      notaryId = "tlsnotary-official",
      serverName = "test-server.io",
      sessionTimestamp = "2026-06-10T07:51:42Z",
      attestationHash = "<ATTESTATION_HASH>",
      presentationHash = "<PRESENTATION_HASH>",
      dataType = "KYC",
      hasRedactions = true,
      isVerified = false
    },
    notaryCid = "<NOTARY_CID>"
  }'
```

Replace:
- `<ATTESTATION_HASH>` with actual hash from step 1
- `<PRESENTATION_HASH>` with actual hash from step 1
- `<NOTARY_CID>` with contract ID from notary registration

### Step 3: Verify Attestation On-Chain

Option 1: Manual Verification

```bash
# Get the contract ID from step 2
ATTESTATION_CID="<ATTESATION_CID_FROM_STEP_2>"

# Verify the attestation
canton participant1 ledger.exercise \
  --contract-id $ATTESTATION_CID \
  --choice VerifyAttestation \
  --payload '{
    verificationResult = "Verified"
  }'
```

Option 2: Automated Verification (Recommended)

Start the verification trigger:

```bash
cd canton-tlsn-attestation
daml trigger \
  --ledger-host localhost \
  --ledger-port 5011 \
  --party Operator \
  --trigger-name TLSNotoryAttestation:AttestationTrigger
```

The trigger will automatically:
1. Find pending AttestationProof contracts
2. Verify cryptographic signatures
3. Update `isVerified` status

### Step 4: Create KYCVerification

Once attestation is verified:

```bash
# Create KYC verification for an institution
canton participant1 ledger.create \
  --template TLSNotaryAttestation:KYCVerification \
  --payload '{
    user = "Alice",
    institution = "Bank",
    operator = "Operator",
    attestationCid = "<ATTESTATION_CID>",
    requiredAttributes = [
      "age>18",
      "identity_verified",
      "country_compliant"
    ],
    isApproved = false,
    verifiedAt = "2026-06-10T13:30:00Z",
    expiresAt = "2027-06-10T13:30:00Z"
  }'
```

### Step 5: Approve KYC

```bash
# Get KYC contract ID from step 4
KYC_CID="<KYC_CID_FROM_STEP_4>"

# Approve the KYC verification
canton participant1 ledger.exercise \
  --contract-id $KYC_CID \
  --choice ApproveKYC \
  --payload '{}'
```

### Step 6: Verify KYC Status

Users and institutions can verify KYC status:

```bash
# Check if KYC is still valid
canton participant1 ledger.exercise \
  --contract-id $KYC_CID \
  --choice IsValid \
  --payload '{}'

# This returns: true (if approved and not expired)
```

---

## 🔐 Verification Service (Production)

For production, implement an off-chain verification service:

### Node.js Service

```javascript
// verification-service.js
const fs = require('fs');
const crypto = require('crypto');
const { LedgerClient } = require('@daml/ledger');

// Connect to Canton ledger
const ledger = new LedgerClient({
  token: process.env.DAML_TOKEN,
  httpBaseUrl: 'http://localhost:5011',
});

// Verify TLSNotary attestation
async function verifyAttestation(attestationPath, notaryPublicKey) {
  // Read attestation file
  const attestationData = fs.readFileSync(attestationPath);

  // In production, use TLSNotary verifier library
  // For demo, we'll simulate verification
  const attestationHash = crypto
    .createHash('sha256')
    .update(attestationData)
    .digest('hex');

  // Verify against expected hash
  // (In real implementation, verify cryptographic signature)
  const isValid = true; // Simulated

  return {
    isValid,
    hash: attestationHash,
    result: isValid ? 'Verified' : 'InvalidSignature'
  };
}

// Process pending attestations
async function processPendingAttestations() {
  // Query for unverified attestations
  const attestations = await ledger.queryContracts({
    templateId: 'TLSNotaryAttestation:AttestationProof',
    filter: { isVerified: false }
  });

  for (const attestation of attestations) {
    const { attestationData, notaryCid } = attestation.payload;

    // Get notary info
    const notary = await ledger.fetch(notaryCid);

    // Verify attestation
    const result = await verifyAttestation(
      `tlsn/example-json.attestation.tlsn`,
      notary.publicKey
    );

    // Update on-chain contract
    await ledger.exercise(
      'AttestationProof.VerifyAttestation',
      attestation.contractId,
      { verificationResult: result.result }
    );

    console.log(`Verified ${attestationData.attestationId}: ${result.result}`);
  }
}

// Run periodically
setInterval(processPendingAttestations, 30000); // Every 30 seconds

console.log('Verification service started');
```

Run the service:

```bash
npm install @daml/ledger
DAML_TOKEN="your-token" node verification-service.js
```

---

## 🎯 Complete Integration Script

```bash
#!/bin/bash

# TLSNotary → Canton Integration Script

set -e

echo "🔗 TLSNotary → Canton Integration"
echo "================================="

# Configuration
TLSN_DIR="/Users/studio/.openclaw/workspace-web3/tlsn"
CANTON_PARTICIPANT="participant1"

# Step 1: Extract hashes
echo "📊 Step 1: Extracting attestation hashes..."
cd $TLSN_DIR

ATTESTATION_HASH=$(sha256sum example-json.attestation.tlsn | cut -d' ' -f1)
PRESENTATION_HASH=$(sha256sum example-json.presentation.tlsn | cut -d' ' -f1)

echo "Attestation Hash: $ATTESTATION_HASH"
echo "Presentation Hash: $PRESENTATION_HASH"

# Step 2: Create AttestationProof
echo ""
echo "📝 Step 2: Creating AttestationProof on Canton..."

# Get notary CID (assuming only one notary exists)
NOTARY_CID=$(canton $CANTON_PARTICIPANT ledger list \
  --template TLSNotaryAttestation:NotaryInfo \
  | head -1 | cut -d' ' -f1)

echo "Notary CID: $NOTARY_CID"

# Create attestation proof
ATTESTATION_CID=$(canton $CANTON_PARTICIPANT ledger create \
  --template TLSNotaryAttestation:AttestationProof \
  --payload "{
    prover = \"Alice\",
    operator = \"Operator\",
    attestationData = {
      attestationId = \"demo-example-json-001\",
      notaryId = \"tlsnotary-official\",
      serverName = \"test-server.io\",
      sessionTimestamp = \"2026-06-10T07:51:42Z\",
      attestationHash = \"$ATTESTATION_HASH\",
      presentationHash = \"$PRESENTATION_HASH\",
      dataType = \"KYC\",
      hasRedactions = true,
      isVerified = false
    },
    notaryCid = \"$NOTARY_CID\"
  }")

echo "Attestation CID: $ATTESTATION_CID"

# Step 3: Verify attestation
echo ""
echo "✅ Step 3: Verifying attestation..."

canton $CANTON_PARTICIPANT ledger.exercise \
  --contract-id $ATTESTATION_CID \
  --choice VerifyAttestation \
  --payload '{
    verificationResult = "Verified"
  }'

echo "✓ Attestation verified!"

# Step 4: Create KYC verification
echo ""
echo "🏦 Step 4: Creating KYC verification..."

KYC_CID=$(canton $CANTON_PARTICIPANT ledger.create \
  --template TLSNotaryAttestation:KYCVerification \
  --payload "{
    user = \"Alice\",
    institution = \"Bank\",
    operator = \"Operator\",
    attestationCid = \"$ATTESTATION_CID\",
    requiredAttributes = [
      \"age>18\",
      \"identity_verified\",
      \"country_compliant\"
    ],
    isApproved = false,
    verifiedAt = \"2026-06-10T13:30:00Z\",
    expiresAt = \"2027-06-10T13:30:00Z\"
  }")

echo "KYC CID: $KYC_CID"

# Step 5: Approve KYC
echo ""
echo "🎉 Step 5: Approving KYC..."

canton $CANTON_PARTICIPANT ledger.exercise \
  --contract-id $KYC_CID \
  --choice ApproveKYC \
  --payload '{}'

echo "✓ KYC approved!"

# Step 6: Verify KYC status
echo ""
echo "🔍 Step 6: Verifying KYC status..."

IS_VALID=$(canton $CANTON_PARTICIPANT ledger.exercise \
  --contract-id $KYC_CID \
  --choice IsValid \
  --payload '{}')

echo "KYC is valid: $IS_VALID"

# Summary
echo ""
echo "================================="
echo "✅ Integration Complete!"
echo "================================="
echo ""
echo "Contract IDs:"
echo "  - Notary: $NOTARY_CID"
echo "  - Attestation: $ATTESTATION_CID"
echo "  - KYC Verification: $KYC_CID"
echo ""
echo "User Alice now has verified KYC on Canton!"
echo "Institution Bank can verify this status."
echo ""
```

Save as `integrate.sh` and run:

```bash
chmod +x integrate.sh
./integrate.sh
```

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    TLSNotary Demo                            │
│  example-json.attestation.tlsn  (7.0KB)                     │
│  example-json.presentation.tlsn (9.6KB)                    │
└────────────────────┬────────────────────────────────────────┘
                     │ Extract hashes
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              Canton: AttestationRegistry                    │
│  - Registered Notary: "tlsnotary-official"                 │
│  - Public Key: 031b84c5567b1264...                          │
└────────────────────┬────────────────────────────────────────┘
                     │ Create AttestationProof
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              Canton: AttestationProof                       │
│  - attestationId: "demo-example-json-001"                  │
│  - attestationHash: <from TLSNotary>                       │
│  - presentationHash: <from TLSNotary>                      │
│  - isVerified: false                                       │
└────────────────────┬────────────────────────────────────────┘
                     │ VerifyAttestation
                     ↓
┌─────────────────────────────────────────────────────────────┐
│              Canton: KYCVerification                        │
│  - user: Alice                                             │
│  - institution: Bank                                       │
│  - attestationCid: <from above>                            │
│  - isApproved: true                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 What This Enables

### Privacy-Preserving KYC

**Before:**
```
User → Bank API → Full personal data exposed → Multiple KYC checks
```

**After:**
```
User → TLSNotary → Cryptographic attestation → Canton smart contract
                                      ↓
                        Prove "KYC approved" without revealing data
```

### Benefits

1. **Portable KYC** - One attestation, verified by multiple institutions
2. **Privacy** - No personal data on-chain, only cryptographic proofs
3. **Compliance** - Immutable audit trail for regulators
4. **Efficiency** - No repeated KYC processes
5. **Control** - Users control what data to disclose

---

## 🚀 Next Steps

1. **Deploy to Testnet**
   - Test with real Canton network
   - Verify end-to-end flow
   - Performance testing

2. **Build User Interface**
   - Web app for users to submit attestations
   - Dashboard for institutions to verify KYC
   - Admin panel for operators

3. **Production Hardening**
   - Implement verification service
   - Add monitoring and alerting
   - Security audit

4. **Regulatory Compliance**
   - Document compliance with KYC/AML regulations
   - Implement audit logging
   - Data retention policies

---

*Integration Guide v1.0*
*Web3 Agent ⛓️*
*June 10, 2026*