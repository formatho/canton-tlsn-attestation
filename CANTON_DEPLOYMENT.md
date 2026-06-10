# Canton Network Deployment Guide

## 🚀 Production Deployment

Complete guide for deploying Canton TLSNotary Attestation to Canton Network.

---

## 📋 Prerequisites

### Software Requirements

- **Canton** (latest version)
- **DAML SDK** (3.3.0+)
- **PostgreSQL** (for production storage)
- **OpenSSL** (for TLS certificates)

### Network Requirements

- Canton Network participant
- PostgreSQL database
- TLS certificates (production)
- Network connectivity to Canton domains

---

## 🔧 Phase 1: Setup Canton Participant

### 1.1 Install Canton

```bash
# Download Canton
curl -L https://github.com/digital-asset/daml/releases/download/v2.9.0/canton-2.9.0.tar.gz -o canton.tar.gz
tar -xzf canton.tar.gz
cd canton-2.9.0

# Or use Homebrew (macOS)
brew tap digital-asset/daml
brew install canton
```

### 1.2 Setup PostgreSQL

```bash
# Install PostgreSQL
brew install postgresql  # macOS
# or
sudo apt-get install postgresql  # Ubuntu

# Start PostgreSQL
brew services start postgresql  # macOS
# or
sudo systemctl start postgresql  # Ubuntu

# Create database
createdb canton

# Create user (with password)
psql canton
CREATE USER canton WITH PASSWORD 'canton';
GRANT ALL PRIVILEGES ON DATABASE canton TO canton;
\q
```

### 1.3 Generate TLS Certificates

For development (self-signed):
```bash
# Create certs directory
mkdir -p certs

# Generate CA certificate
openssl genrsa -out certs/root-ca-key.pem 4096
openssl req -new -x509 -days 3650 -key certs/root-ca-key.pem -out certs/root-ca.pem

# Generate participant certificate
openssl genrsa -out certs/participant1-key.pem 2048
openssl req -new -key certs/participant1-key.pem -out certs/participant1.csr
openssl x509 -req -days 365 -in certs/participant1.csr \
  -CA certs/root-ca.pem -CAkey certs/root-ca-key.pem \
  -CAcreateserial -out certs/participant1.pem

# Generate domain certificate
openssl genrsa -out certs/domain-key.pem 2048
openssl req -new -key certs/domain-key.pem -out certs/domain.csr
openssl x509 -req -days 365 -in certs/domain.csr \
  -CA certs/root-ca.pem -CAkey certs/root-ca-key.pem \
  -CAcreateserial -out certs/domain.pem
```

For production:
- Use certificates from your organization's CA
- Ensure proper CN/SAN fields
- Use strong key sizes (4096 bits)

---

## 🏗️ Phase 2: Start Canton Network

### 2.1 Start Domain

```bash
# Start Canton domain
canton domains.mydomain start --config canton.conf
```

### 2.2 Start Participant

```bash
# Start Canton participant
canton participant1 start --config canton.conf
```

### 2.3 Verify Status

```bash
# Check domain health
canton domains.mydomain health

# Check participant health
canton participant1 health

# List connected domains
canton participant1 domains.list
```

---

## 📦 Phase 3: Deploy Smart Contracts

### Option 1: Automated Deployment

```bash
./deploy.sh
```

This script:
- Builds DAML package
- Uploads to Canton
- Creates AttestationRegistry
- Registers TLSNotary notary
- Starts verification trigger

### Option 2: Manual Deployment

#### 3.1 Build DAML Package

```bash
cd daml
daml build
```

#### 3.2 Upload to Canton

```bash
daml ledger upload participant1 \
  --package-file .daml/dist/canton-tlsn-attestation-1.0.0.dar
```

#### 3.3 Create AttestationRegistry

```bash
canton participant1 ledger create \
  --template TLSNotaryAttestation:AttestationRegistry \
  --payload 'operator = "Operator", notaries = {}'
```

Save the contract ID returned.

#### 3.4 Register TLSNotary Notary

```bash
canton participant1 ledger.exercise \
  --contract-id <REGISTRY_CID> \
  --choice RegisterNotary \
  --payload '{
    notaryId = "tlsnotary-official",
    publicKey = "031b84c5567b126440995d3ed5aaba0565d71e1834604819ff9c17f5e9d5dd078f",
    name = "TLSNotary Official Notary Service",
    expiresAt = null
  }'
```

#### 3.5 Start Verification Trigger

```bash
daml trigger \
  --ledger-host localhost \
  --ledger-port 5011 \
  --party Operator \
  --trigger-name TLSNotaryAttestation:AttestationTrigger
```

---

## ✅ Phase 4: Verify Deployment

### 4.1 Check Deployed Packages

```bash
daml ledger list-participant-packages participant1
```

Expected output:
```
Package: canton-tlsn-attestation:1.0.0
Modules:
  - TLSNotaryAttestation
  - TLSNotaryAttestation.Examples
  - TLSNotaryAttestation.Tests
  - TLSNotaryAttestation.IntegrationTests
```

### 4.2 Check Contracts

```bash
canton participant1 ledger list \
  --template TLSNotaryAttestation:AttestationRegistry

canton participant1 ledger list \
  --template TLSNotaryAttestation:NotaryInfo
```

### 4.3 Test Contract

```bash
cd daml
daml script --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar \
  --script-name TLSNotaryAttestation.Examples:exampleKYCFlow \
  --argument 'operator = "Operator", user = "Alice", institution = "Bank"'
```

---

## 🌐 Phase 5: Connect to Public Canton Network

### 5.1 Request Network Access

1. Contact Canton Network: https://www.canton.network
2. Request participant credentials
3. Obtain domain connection details

### 5.2 Configure for Public Network

Update `canton.conf`:

```hocon
domains:
  canton-network-public:
    public-api:
      address: "public.canton.network"
      port: 443

    tls:
      cert-chain-file: "certs/participant1.pem"
      private-key-file: "certs/participant1-key.pem"
      trust-collection-file: "certs/canton-network-ca.pem"
```

### 5.3 Connect Participant

```bash
canton participant1 connect --domain canton-network-public
```

---

## 🔒 Phase 6: Security Hardening

### 6.1 Enable SSL/TLS

```hocon
canton:
  participants:
    participant1:
      ledger-api:
        tls:
          cert-chain-file: "certs/participant1.pem"
          private-key-file: "certs/participant1-key.pem"
```

### 6.2 Enable Authentication

```hocon
canton:
  participants:
    participant1:
      ledger-api:
        auth:
          type: jwt-hmac
          secret: "your-secret-key"
```

### 6.3 Configure Firewall

```bash
# Allow only necessary ports
ufw allow 5011/tcp  # Ledger API
ufw allow 5012/tcp  # Admin API
ufw enable
```

---

## 📊 Phase 7: Monitoring

### 7.1 Setup Metrics

```bash
canton participant1 ledger api metrics \
  --prometheus 9090
```

### 7.2 View Metrics

```bash
curl http://localhost:9090/metrics
```

### 7.3 Setup Logging

```bash
# Monitor logs
tail -f /var/log/canton/participant1.log

# Search for errors
grep ERROR /var/log/canton/participant1.log
```

---

## 🚨 Phase 8: Production Checklist

- [ ] PostgreSQL configured for production
- [ ] SSL/TLS certificates from trusted CA
- [ ] Authentication enabled
- [ ] Firewall rules configured
- [ ] Backup strategy in place
- [ ] Monitoring setup
- [ ] Log aggregation configured
- [ ] Disaster recovery plan
- [ ] Load testing completed
- [ ] Security audit performed

---

## 📈 Phase 9: Scaling

### 9.1 Multiple Participants

```bash
# Start additional participants
canton participant2 start --config canton.conf
canton participant3 start --config canton.conf
```

### 9.2 Load Balancing

Use HAProxy or similar:
```hocon
participants:
  participant1:
    ledger-api:
      address: "0.0.0.0"
      port: 5011
```

Configure load balancer to distribute requests.

### 9.3 Database Scaling

```bash
# Use connection pooling
# Configure replication
# Setup read replicas
```

---

## 🔄 Phase 10: Maintenance

### Update Contracts

```bash
# Build new version
cd daml
daml build

# Upload new version
daml ledger upload participant1 \
  --package-file .daml/dist/canton-tlsn-attestation-1.1.0.dar

# Migrate contracts (if needed)
# Update triggers
```

### Backup

```bash
# Backup PostgreSQL
pg_dump canton > canton-backup-$(date +%Y%m%d).sql

# Backup configuration
tar -czf canton-config-backup-$(date +%Y%m%d).tar.gz canton.conf certs/
```

### Restore

```bash
# Restore PostgreSQL
psql canton < canton-backup-20260610.sql

# Restore configuration
tar -xzf canton-config-backup-20260610.tar.gz
```

---

## 📞 Support

- **Canton Network**: https://www.canton.network
- **DAML Docs**: https://docs.daml.com
- **TLSNotary**: https://tlsnotary.org

---

## 🔗 Quick Links

- Repository: https://github.com/formatho/canton-tlsn-attestation
- Canton Network: https://www.canton.network
- DAML SDK: https://get.daml.com

---

*Deployment Guide v1.0*
*Web3 Agent ⛓️*
*June 10, 2026*