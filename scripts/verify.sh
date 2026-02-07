#!/usr/bin/env bash
# Verify deployed UniYield contracts on Etherscan/Basescan/etc.
# Run from repo root: ./scripts/verify.sh
#
# Required env (set in .env or export):
#   CHAIN            - Chain name (e.g. mainnet, base, base-sepolia)
#   ETHERSCAN_API_KEY - API key from etherscan.io, basescan.org, etc.
#   DIAMOND_ADDRESS  - Deployed diamond
#   DIAMOND_CUT_FACET - DiamondCutFacet address (for diamond constructor args)
#   CONTRACT_OWNER   - Diamond owner address (for diamond constructor args)
#   DIAMOND_LOUPE_FACET
#   DIAMOND_OWNERSHIP_FACET
#   VAULT_CORE_FACET
#   STRATEGY_REGISTRY_FACET
#   REBALANCE_FACET
#
# Optional (strategy facets):
#   AAVE_STRATEGY_FACET, COMPOUND_STRATEGY_FACET, MORPHO_STRATEGY_FACET

set -e
cd "$(dirname "$0")/.."

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

CHAIN="${CHAIN:-mainnet}"
API_KEY="${ETHERSCAN_API_KEY:-}"

die() { echo "Error: $*" >&2; exit 1; }

[ -n "$API_KEY" ]    || die "ETHERSCAN_API_KEY not set"
[ -n "$DIAMOND_ADDRESS" ] || die "DIAMOND_ADDRESS not set"
[ -n "$DIAMOND_CUT_FACET" ] || die "DIAMOND_CUT_FACET not set"
[ -n "$CONTRACT_OWNER" ] || die "CONTRACT_OWNER not set"
[ -n "$DIAMOND_LOUPE_FACET" ] || die "DIAMOND_LOUPE_FACET not set"
[ -n "$DIAMOND_OWNERSHIP_FACET" ] || die "DIAMOND_OWNERSHIP_FACET not set"
[ -n "$VAULT_CORE_FACET" ] || die "VAULT_CORE_FACET not set"
[ -n "$STRATEGY_REGISTRY_FACET" ] || die "STRATEGY_REGISTRY_FACET not set"
[ -n "$REBALANCE_FACET" ] || die "REBALANCE_FACET not set"

DIAMOND_ARGS=$(cast abi-encode "constructor(address,address)" "$CONTRACT_OWNER" "$DIAMOND_CUT_FACET")

verify() {
  local addr=$1
  local contract=$2
  local extra_args=${3:-}
  echo "Verifying $contract at $addr..."
  forge verify-contract "$addr" "$contract" \
    --chain "$CHAIN" \
    -e "$API_KEY" \
    --watch \
    $extra_args
}

verify "$DIAMOND_ADDRESS" "src/UniYieldDiamond.sol:UniYieldDiamond" "--constructor-args $DIAMOND_ARGS"
verify "$DIAMOND_CUT_FACET" "src/diamond/DiamondCutFacet.sol:DiamondCutFacet"
verify "$DIAMOND_LOUPE_FACET" "src/diamond/DiamondLoupeFacet.sol:DiamondLoupeFacet"
verify "$DIAMOND_OWNERSHIP_FACET" "src/diamond/DiamondOwnershipFacet.sol:DiamondOwnershipFacet"
verify "$VAULT_CORE_FACET" "src/vault/VaultCoreFacet.sol:VaultCoreFacet"
verify "$STRATEGY_REGISTRY_FACET" "src/vault/StrategyRegistryFacet.sol:StrategyRegistryFacet"
verify "$REBALANCE_FACET" "src/vault/RebalanceFacet.sol:RebalanceFacet"

# Strategy facets (optional). Constructor args must match deployment.
# If deployed via DeployStrategy, vault param is address(0); via InitVault DEPLOY_STRATEGY=1, use DIAMOND_ADDRESS.
STRATEGY_VAULT="${STRATEGY_VAULT:-$DIAMOND_ADDRESS}"

if [ -n "$AAVE_STRATEGY_FACET" ]; then
  AAVE_POOL="${AAVE_POOL:-0x0000000000000000000000000000000000000000}"
  AAVE_A_TOKEN="${AAVE_A_TOKEN:-0x0000000000000000000000000000000000000000}"
  AAVE_ARGS=$(cast abi-encode "constructor(address,address,address)" "$AAVE_POOL" "$AAVE_A_TOKEN" "$STRATEGY_VAULT")
  verify "$AAVE_STRATEGY_FACET" "src/strategies/AaveStrategyFacet.sol:AaveStrategyFacet" "--constructor-args $AAVE_ARGS"
fi

if [ -n "$COMPOUND_STRATEGY_FACET" ]; then
  COMPOUND_COMET="${COMPOUND_COMET:-0x0000000000000000000000000000000000000000}"
  COMPOUND_ARGS=$(cast abi-encode "constructor(address,address)" "$COMPOUND_COMET" "$STRATEGY_VAULT")
  verify "$COMPOUND_STRATEGY_FACET" "src/strategies/CompoundStrategyFacet.sol:CompoundStrategyFacet" "--constructor-args $COMPOUND_ARGS"
fi

if [ -n "$MORPHO_STRATEGY_FACET" ]; then
  MORPHO="${MORPHO:-0x0000000000000000000000000000000000000000}"
  MORPHO_LOAN="${MORPHO_LOAN_TOKEN:-0x0000000000000000000000000000000000000000}"
  MORPHO_COLL="${MORPHO_COLLATERAL_TOKEN:-0x0000000000000000000000000000000000000000}"
  MORPHO_ORACLE="${MORPHO_ORACLE:-0x0000000000000000000000000000000000000000}"
  MORPHO_IRM="${MORPHO_IRM:-0x0000000000000000000000000000000000000000}"
  MORPHO_LLTV="${MORPHO_LLTV:-0}"
  MORPHO_ARGS=$(cast abi-encode "constructor(address,address,address,address,address,uint256,address)" \
    "$MORPHO" "$MORPHO_LOAN" "$MORPHO_COLL" "$MORPHO_ORACLE" "$MORPHO_IRM" "$MORPHO_LLTV" "$STRATEGY_VAULT")
  verify "$MORPHO_STRATEGY_FACET" "src/strategies/MorphoStrategyFacet.sol:MorphoStrategyFacet" "--constructor-args $MORPHO_ARGS"
fi

echo "All contracts verified."
