# Canton TLSNotary Deployment Guide

## 🚀 Production Deployment

Step-by-step guide to deploy TLSNotary attestation verification on Canton Network.

---

## 📋 Prerequisites

### Software Requirements
- Canton (latest version)
- DAML SDK 3.3.0+
- TLSNotary Rust library (for verification service)
- Node.js 18+ (for verification service)

### Network Requirements
- Canton participant node
- Network connectivity to Canton Network
- Access to trusted Notary services

---

## 🔧 Phase 1: Setup Canton Environment

### 1. Install Canton

```bash
# Download Canton
curl -L https://github.com/digital-asset/daml/releases/download/v2.9.0/canton-2.9.0.tar.gz -o canton.tar.gz
tar -xzf canton.tar.gz
cd canton-2.9.0

# Or use Homebrew (macOS)
brew tap digital-asset/daml
brew install canton
```

### 2. Configure Canton Participant

Create `canton.conf`:

```hocon
canton {
  participants {
    participant1 {
      storage {
        type = memory
        # For production, use PostgreSQL:
        # type = postgres
        # config {
        #   dataSource {
        #     className = org.postgresql.ds.PGSimpleDataSource
        #     url = "jdbc:postgresql://localhost:5432/canton"
        #     user = canton
        #     password = password
        #   }
        # }
      }

      ledger-api {
        address = "0.0.0.0"
        port = 5011
      }

      admin-api {
        address = "0.0.0.0"
        port = 5012
      }
    }
  }

  domains {
    mydomain {
      init {
        domainParameters = {
          uniqueContractKeys = true
          maxReassignmentRate = 1000
        }
      }

      public-api {
        address = "0.0.0.0"
        port = 5013
      }

      admin-api {
        address = "0.0.0.0"
        port = 5014
      }
    }
  }
}
```

### 3. Start Canton

```bash
# Start participant
canton participant1 start --config canton.conf

# In another terminal, start domain
canton domains.mydomain start --config canton.conf

# Connect participant to domain
canton participant1 connect --domain mydomain
```

---

## 📦 Phase 2: Build and Deploy DAML Contracts

### 1. Build the DAML Package

```bash
cd canton-tlsn-attestation/daml
daml build
```

This creates `.daml/dist/canton-tlsn-attestation-1.0.0.dar`

### 2. Upload to Canton

```bash
# Upload package
daml ledger upload participant1 \
  --package-file .daml/dist/canton-tlsn-attestation-1.0.0.dar

# Verify upload
daml ledger list-participant-packages participant1
```

### 3. Initialize with Navigator (Optional)

```bash
# Start Navigator UI
daml navigator

# Open browser to http://localhost:7509
# Sign in with participant credentials
```

---

## 🤖 Phase 3: Deploy Verification Service

### 1. Create Verification Service

Create `verification-service/index.js`:

```javascript
const { TLSNotaryVerifier } = require('tlsn-verifier');
const express = require('express');
const { LedgerClient } = require('@daml/ledger');

const app = express();
app.use(express.json());

// Connect to Canton ledger
const ledger = new LedgerClient({
  token: process.env.DAML_TOKEN,
  httpBaseUrl: 'http://localhost:5011',
});

// Verify TLSNotary attestation
app.post('/verify', async (req, res) => {
  try {
    const { attestationFile, notaryPublicKey } = req.body;

    // Create verifier
    const verifier = new TLSNotaryVerifier(notaryPublicKey);

    // Verify attestation
    const isValid = await verifier.verify(attestationFile);

    if (isValid) {
      // Update on-chain contract
      await ledger.exercise(
        'AttestationProof.VerifyAttestation',
        req.body.contractId,
        { verificationResult: 'Verified' }
      );

      res.json({ success: true, result: 'Verified' });
    } else {
      res.json({ success: false, result: 'InvalidSignature' });
    }
  } catch (error) {
    console.error('Verification failed:', error);
    res.status(500).json({ error: error.message });
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Verification service running on port ${PORT}`);
});
```

### 2. Install Dependencies

```bash
mkdir verification-service
cd verification-service
npm init -y
npm install express tlsn-verifier @daml/ledger
```

### 3. Start Service

```bash
DAML_TOKEN="your-token-here" node index.js
```

---

## 🏛️ Phase 4: Initialize Contracts

### 1. Create Attestation Registry

```bash
# Using Canton console
canton participant1 ledger.create \
  --template TLSNotaryAttestation:AttestationRegistry \
  --payload 'operator = "Operator", notaries = {}'
```

### 2. Register Trusted Notary

```bash
# Register TLSNotary official notary
canton participant1 ledger.exercise \
  --contract-id <registry-cid> \
  --choice RegisterNotary \
  --payload '{
    notaryId = "tlsnotary-official",
    publicKey = "031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f",
    name = "TLSNotary Official Notary Service",
    expiresAt = null
  }'
```

### 3. Create AttestationProof for User

```bash
# User submits their attestation
canton participant1 ledger.create \
  --template TLSNotaryAttestation:AttestationProof \
  --payload '{
    prover = "Alice",
    operator = "Operator",
    attestationData = {
      attestationId = "user-001-attestation",
      notaryId = "tlsnotary-official",
      serverName = "kyc-provider.example.com",
      sessionTimestamp = "2026-06-10T07:51:42Z",
      attestationHash = "a1b2c3d4e5f6...",
      presentationHash = "f1e2d3c4b5a6...",
      dataType = "KYC",
      hasRedactions = true,
      isVerified = false
    },
    notaryCid = "<notary-contract-id>"
  }'
```

---

## 🔄 Phase 5: Automated Verification

### 1. Deploy Trigger

```bash
# Start trigger for automated verification
daml trigger \
  --ledger-host localhost \
  --ledger-port 5011 \
  --party Operator \
  --trigger-name TLSNotaryAttestation:AttestationTrigger
```

The trigger will:
- Automatically verify pending attestations
- Check for expired verifications
- Maintain verification status

---

## 🧪 Phase 6: Testing

### Test Complete Flow

```bash
# 1. Create user attestation
USER_CID=$(canton participant1 ledger.create \
  --template TLSNotaryAttestation:AttestationProof \
  --payload '<user-attestation-payload>')

# 2. Verify attestation
curl -X POST http://localhost:3000/verify \
  -H "Content-Type: application/json" \
  -d '{
    "attestationFile": "...",
    "notaryPublicKey": "031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f",
    "contractId": "'$USER_CID'"
  }'

# 3. Create KYC verification
KYC_CID=$(canton participant1 ledger.create \
  --template TLSNotaryAttestation:KYCVerification \
  --payload '<kyc-verification-payload>')

# 4. Approve KYC
canton participant1 ledger.exercise \
  --contract-id $KYC_CID \
  --choice ApproveKYC \
  --payload '{}'

# 5. Verify KYC status
canton participant1 ledger.exercise \
  --contract-id $KYC_CID \
  --choice IsValid \
  --payload '{}'
```

---

## 🔒 Phase 7: Security Hardening

### 1. Configure SSL/TLS

```hocon
canton {
  participants {
    participant1 {
      ledger-api {
        address = "0.0.0.0"
        port = 5011
        tls {
          cert-chain-file = "/path/to/cert.pem"
          private-key-file = "/path/to/key.pem"
          trust-collection-file = "/path/to/ca.pem"
        }
      }
    }
  }
}
```

### 2. Enable Authentication

```hocon
canton {
  participants {
    participant1 {
      ledger-api {
        auth {
          type = jwt-hmac
          secret = "your-secret-key"
        }
      }
    }
  }
}
```

### 3. Setup Monitoring

```bash
# Enable metrics
canton participant1 ledger api metrics \
  --prometheus 9090

# View metrics
curl http://localhost:9090/metrics
```

---

## 📊 Phase 8: Production Checklist

- [ ] Use PostgreSQL for storage (not memory)
- [ ] Enable SSL/TLS for all connections
- [ ] Implement proper authentication
- [ ] Setup monitoring and alerting
- [ ] Configure backup and disaster recovery
- [ ] Use production Notary services
- [ ] Implement rate limiting
- [ ] Setup audit logging
- [ ] Configure key rotation
- [ ] Test disaster recovery procedures

---

## 🚨 Troubleshooting

### Common Issues

**Issue: Package upload fails**
```bash
# Check participant status
canton participant1 health

# Retry upload
daml ledger upload participant1 --package-file .daml/dist/canton-tlsn-attestation-1.0.0.dar
```

**Issue: Verification service can't connect**
```bash
# Check Canton is running
curl http://localhost:5011/health

# Check token validity
echo $DAML_TOKEN
```

**Issue: Trigger not running**
```bash
# Check trigger logs
daml trigger --list

# Restart trigger
daml trigger --stop <trigger-id>
daml trigger --start <trigger-name>
```

---

## 📈 Performance Optimization

### 1. Enable Caching

```hocon
canton {
  participants {
    participant1 {
      caching {
        enable-transaction-caching = true
        max-entries = 10000
      }
    }
  }
}
```

### 2. Optimize Queries

```daml
-- Use indexed queries
@lookupBy("KYCVerification", "user")
fetch @Party KYCVerification
```

### 3. Batch Operations

```javascript
// Batch verify attestations
const attestations = await ledger.queryContracts({
  templateId: 'TLSNotaryAttestation:AttestationProof',
  filter: { isVerified: false }
});

await Promise.all(
  attestations.map(a => verifyAttestation(a.contractId))
);
```

---

## 🔗 Next Steps

1. **Scale horizontally** - Deploy multiple participant nodes
2. **Multi-domain deployment** - Connect to multiple Canton domains
3. **Advanced verification** - Add custom verification rules
4. **Audit dashboard** - Build UI for monitoring verification status
5. **Integration testing** - Automated end-to-end tests

---

*Deployment Guide v1.0*
*Web3 Agent ⛓️*