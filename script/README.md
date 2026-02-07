# Deployment Scripts

## DeployDiamond

Deploys the UniYield diamond and all core facets (Loupe, Ownership, VaultCore, StrategyRegistry, Rebalance), then performs `diamondCut` to wire them.

**Dry-run (simulation):**

```bash
forge script script/DeployDiamond.s.sol:DeployDiamond --sig "run()"
```

**Deploy (use a funded deployer key):**

```bash
export PRIVATE_KEY=0x...
forge script script/DeployDiamond.s.sol:DeployDiamond --sig "run()" --broadcast --rpc-url <RPC_URL> --fork-url <RPC_URL>
```

> **Important:** `--fork-url` is required so simulation runs against the real chain state (including the deployer's nonce). Without it, simulation uses nonce 0 and the diamondCut transactions will revert due to address mismatch.

Optional: `CONTRACT_OWNER` – used as diamond owner when `PRIVATE_KEY` is not set (simulation only). With `PRIVATE_KEY`, owner is `vm.addr(PRIVATE_KEY)`.

---

## DeployStrategy

Deploys strategy facets (Aave, Compound, Morpho). Use the printed strategy address / id when calling `addStrategy` or when initializing the vault. Pass protocol addresses via env for real integration; omit for no-op (e.g. dry-run).

**Env:**

- `STRATEGY` – `aave` | `compound` | `morpho` | `all` (default: `aave`)
- `PRIVATE_KEY` – optional; omit for dry-run
- **Aave:** `AAVE_POOL`, `AAVE_A_TOKEN` (Aave V3 Pool and aToken for the vault asset)
- **Compound:** `COMPOUND_COMET` (Comet contract; vault asset must equal comet.baseToken())
- **Morpho:** `MORPHO`, `MORPHO_LOAN_TOKEN`, `MORPHO_COLLATERAL_TOKEN`, `MORPHO_ORACLE`, `MORPHO_IRM`, `MORPHO_LLTV`

```bash
# Deploy Aave strategy only
forge script script/DeployStrategy.s.sol:DeployStrategy --sig "run()" --broadcast --rpc-url <RPC_URL> --fork-url <RPC_URL>

# Deploy all strategies
STRATEGY=all forge script script/DeployStrategy.s.sol:DeployStrategy --sig "run()" --broadcast --rpc-url <RPC_URL> --fork-url <RPC_URL>
```

---

## InitVault

Initializes the vault on an already-deployed diamond and optionally deploys and registers a strategy.

**Required env:**

- `DIAMOND_ADDRESS` – deployed diamond
- `ASSET_ADDRESS` – vault asset (e.g. USDC)
- `VAULT_NAME` – vault share token name
- `VAULT_SYMBOL` – vault share token symbol

**Optional env:**

- `ASSET_DECIMALS` – default 6
- `SHARE_DECIMALS` – default 6
- `MIN_SWITCH_BPS` – default 50 (0.5% min improvement to rebalance)
- `DEPLOY_STRATEGY=1` – deploy AaveStrategyFacet and use it as the only strategy (set `AAVE_POOL` and `AAVE_A_TOKEN` for real integration; omit for no-op)
- `ACTIVE_STRATEGY_ID` – if not using `DEPLOY_STRATEGY`, set to strategy id (strategy facet address as uint256) so `initVault` can set the active strategy
- `PRIVATE_KEY` – deployer; omit for dry-run

**Example (deploy strategy and init in one go):**

```bash
export DIAMOND_ADDRESS=0x...
export ASSET_ADDRESS=0x...
export VAULT_NAME="UniYield USDC"
export VAULT_SYMBOL="uvUSDC"
export DEPLOY_STRATEGY=1
export PRIVATE_KEY=0x...

forge script script/InitVault.s.sol:InitVault --sig "run()" --broadcast --rpc-url <RPC_URL> --fork-url <RPC_URL>
```

**Example (init with an already-deployed strategy):**

```bash
export DIAMOND_ADDRESS=0x...
export ASSET_ADDRESS=0x...
export VAULT_NAME="UniYield USDC"
export VAULT_SYMBOL="uvUSDC"
export ACTIVE_STRATEGY_ID=<strategy_facet_address_as_uint256>
export PRIVATE_KEY=0x...

forge script script/InitVault.s.sol:InitVault --sig "run()" --broadcast --rpc-url <RPC_URL> --fork-url <RPC_URL>
```

After init with `DEPLOY_STRATEGY=1`, you still need to call `addStrategy` and `setActiveStrategy` on the diamond; the script does that when `DEPLOY_STRATEGY=1`.
