#!/usr/bin/env bash
# Export UniYield Diamond ABI for frontend consumption.
# Run from repo root: ./scripts/export-abi.sh

set -e
cd "$(dirname "$0")/.."
forge build --silent
mkdir -p abi
forge inspect IUniYieldDiamond abi --json > abi/UniYieldDiamond.json
echo "Exported abi/UniYieldDiamond.json"
