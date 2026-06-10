# Integration Tests Guide

## 🧪 End-to-End Integration Tests

Complete integration testing for TLSNotary proof generation and submission to Canton smart contracts.

---

## 📋 What It Tests

### Integration Test Flow

```
1. Start TLSNotary test server
   ↓
2. Generate TLSNotary attestation
   - Run attestation_prove example
   - Generate .attestation.tlsn, .presentation.tlsn, .secrets.tlsn
   ↓
3. Create selective disclosure
   - Run attestation_present example
   - Redact sensitive data
   ↓
4. Verify presentation
   - Run attestation_verify example
   - Cryptographic verification
   ↓
5. Extract hashes
   - Calculate SHA256 hashes
   - Prepare attestation data
   ↓
6. Submit to Canton
   - Create AttestationProof contract
   - Verify on-chain
   - Create KYCVerification
   ↓
7. Run DAML integration tests
   - Test complete flow
   - Test multi-institution trust
```

---

## 🚀 Running Integration Tests

### Option 1: Automated Script

```bash
./integration-test.sh
```

This script:
- ✅ Starts TLSNotary server
- ✅ Generates attestation
- ✅ Creates presentation
- ✅ Verifies presentation
- ✅ Calculates hashes
- ✅ Runs DAML integration tests

### Option 2: Manual Steps

```bash
# 1. Start TLSNotary server
cd tlsn
RUST_LOG=info PORT=4000 cargo run --bin tlsn-server-fixture

# 2. In another terminal, generate attestation
RUST_LOG=info SERVER_PORT=4000 cargo run --release --example attestation_prove

# 3. Create presentation
cargo run --release --example attestation_present

# 4. Verify presentation
cargo run --release --example attestation_verify

# 5. Calculate hashes
ATTESTATION_HASH=$(sha256sum example-json.attestation.tlsn | cut -d' ' -f1)
PRESENTATION_HASH=$(sha256sum example-json.presentation.tlsn | cut -d' ' -f1)

# 6. Run DAML integration tests
cd ../canton-tlsn-attestation/daml
daml test --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar \
  --scenario-name "End-to-end TLSNotary integration"
```

---

## 🔧 GitHub Workflow

### Automatic Testing

The integration tests run automatically on:
- ✅ Push to `main` or `develop` branches
- ✅ Pull requests to `main`
- ✅ Manual trigger via GitHub Actions UI

### Workflow Steps

1. **Setup**
   - Install DAML SDK
   - Install Rust toolchain
   - Clone TLSNotary repository

2. **Build**
   - Build TLSNotary with examples
   - Build DAML package
   - Start Canton participant

3. **Test**
   - Run TLSNotary integration tests
   - Run DAML integration tests
   - Upload artifacts and logs

4. **Cleanup**
   - Stop Canton
   - Generate test summary

### Trigger Workflow Manually

```bash
gh workflow run integration-tests.yml
```

Or use GitHub Actions UI:
- Go to Actions tab
- Select "Integration Tests"
- Click "Run workflow"

---

## 📊 Integration Test Coverage

### Test 1: End-to-End TLSNotary Integration

**What it tests:**
- TLSNotary attestation generation
- AttestationProof creation on Canton
- Cryptographic signature verification
- KYCVerification creation and approval

**Key assertions:**
- ✅ Attestation successfully verified
- ✅ KYC verification created
- ✅ KYC approval flow works
- ✅ Multi-party access control

### Test 2: Multi-Institution Trust Flow

**What it tests:**
- One attestation, multiple institutions
- Independent verification by each institution
- Portable reputation model

**Key assertions:**
- ✅ Bank can verify KYC
- ✅ Exchange can verify KYC
- ✅ Insurance can verify KYC
- ✅ All institutions work independently

---

## 📁 Generated Files

Integration tests generate the following artifacts:

```
integration-test-output/
├── server.log                    # TLSNotary server logs
├── notarization.log              # Attestation generation logs
├── presentation.log              # Presentation creation logs
├── verification.log              # Verification logs
├── example-json.attestation.tlsn # TLSNotary attestation
├── example-json.presentation.tlsn # Selective disclosure
├── example-json.secrets.tlsn     # Cryptographic secrets
└── attestation-proof.json        # Canton contract data
```

These files are uploaded as GitHub artifacts for debugging.

---

## 🔍 Troubleshooting

### Issue: TLSNotary build fails

```bash
# Install OpenSSL dependencies
sudo apt-get update
sudo apt-get install -y libssl-dev pkg-config

# Ensure Rust is up to date
rustup update stable
```

### Issue: Canton not available

The workflow gracefully handles missing Canton:
- Tests TLSNotary integration without DAML
- Skips DAML ledger tests
- Still validates end-to-end flow

### Issue: Port already in use

```bash
# Use different port
TLSN_SERVER_PORT=4001 ./integration-test.sh
```

### Issue: DAML tests fail

```bash
# Rebuild DAML package
cd daml
daml clean
daml build

# Run specific test
daml test --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar \
  --scenario-name "End-to-end TLSNotary integration"
```

---

## 📈 CI/CD Integration

### GitHub Workflow Badge

Add to README.md:

```markdown
[![Integration Tests](https://github.com/formatho/canton-tlsn-attestation/actions/workflows/integration-tests.yml/badge.svg)](https://github.com/formatho/canton-tlsn-attestation/actions/workflows/integration-tests.yml)
```

### Status Checks

Integration tests provide status checks for:
- Pull request approval
- Branch protection rules
- Continuous deployment

---

## 🎯 Best Practices

1. **Run locally first**: Always test locally before pushing
2. **Check logs**: Review uploaded artifacts for debugging
3. **Use tags**: Pin TLSNotary to specific versions for stability
4. **Cache dependencies**: Speed up builds with GitHub Actions cache
5. **Test on branches**: Use feature branches for development

---

## 📝 Adding New Integration Tests

### Step 1: Add Test to IntegrationTests.daml

```daml
scenario "New integration test" $ do
  testNewIntegrationFlow
```

### Step 2: Implement Test Logic

```daml
testNewIntegrationFlow : Script ()
testNewIntegrationFlow = do
  -- Setup parties
  alice <- allocateParty "Alice"
  bob <- allocateParty "Bob"

  -- Create contracts
  -- Exercise choices
  -- Make assertions
```

### Step 3: Update GitHub Workflow

```yaml
- name: Run DAML integration tests
  run: |
    daml test --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar \
      --scenario-name "New integration test"
```

---

## 🔗 Resources

- **TLSNotary Docs**: https://tlsnotary.org/docs/intro
- **DAML Testing**: https://docs.daml.com/concepts/tooling/daml-test.html
- **GitHub Actions**: https://docs.github.com/actions

---

*Integration tests created: June 10, 2026*
*Web3 Agent ⛓️*