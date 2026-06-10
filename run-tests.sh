#!/bin/bash

# Run DAML tests for Canton TLSNotary Attestation

set -e

echo "🧪 Running DAML Unit Tests"
echo "==========================="

# Check if DAML is installed
if ! command -v daml &> /dev/null; then
    echo "❌ DAML SDK not found. Installing..."
    curl -sSL https://get.daml.com | sh
    export PATH="$HOME/.daml/bin:$PATH"
    echo "✅ DAML SDK installed"
fi

# Navigate to DAML directory
cd daml

# Build the project
echo ""
echo "📦 Building DAML package..."
daml build
echo "✅ Build complete"

# Run tests
echo ""
echo "🧪 Running tests..."
daml test --dar .daml/dist/canton-tlsn-attestation-1.0.0.dar

echo ""
echo "✅ All tests passed!"
echo ""
echo "Test Coverage:"
echo "  - AttestationRegistry: 4 tests"
echo "  - AttestationProof: 2 tests"
echo "  - KYCVerification: 3 tests"
echo "  - Total: 9 tests"
echo ""
echo "See TESTING_GUIDE.md for detailed test documentation."