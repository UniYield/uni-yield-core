# UniYield Core

UniYield is a single-asset, yield-optimizing vault that deploys user deposits into one lending strategy at a time (Aave, Compound, Morpho). The vault is implemented as an [EIP-2535 Diamond](https://eips.ethereum.org/EIPS/eip-2535) and exposes an [ERC-4626](https://eips.ethereum.org/EIPS/eip-4626) interface: users deposit the underlying asset (e.g. USDC), receive share tokens, and can redeem shares for assets at any time. Yield is earned by routing assets to the strategy that currently offers the best rate; a permissionless rebalance moves funds when another strategy’s rate is higher by a configurable threshold.

## About the protocol

- **Single vault, single asset** – Each diamond is configured with one underlying asset (e.g. USDC). `totalAssets()` is the sum of idle balance in the vault and assets deployed in the active strategy.
- **One active strategy** – At any time, one strategy is “active.” Incoming deposits are sent to that strategy via the vault’s delegatecall; withdrawals pull from the strategy (and idle) as needed.
- **Strategy set** – The owner registers multiple strategies (each strategy is a separate contract; its address is used as the strategy id). Each strategy has config: `enabled`, `targetBps`, `maxBps` (for future allocation logic). Only enabled strategies are considered for rebalancing.
- **Permissionless rebalance** – Anyone may call `rebalance()`. The contract exits the current strategy (bringing assets back to the vault), compares all enabled strategies’ rates (in bps), and if another strategy’s rate is higher than the current one by at least `minSwitchBps`, it becomes the new active strategy and all idle assets are deposited there. `previewRebalance()` returns the would-be `fromId`, `toId`, and `assetsToMove` without executing.
- **Share accounting** – Shares are minted/burned using ERC-4626 semantics. Conversion between assets and shares uses `totalAssets()` and `totalSupply()`; new deposits are auto-deployed to the active strategy after minting.

## User flows

- **Deposit** – `deposit(assets, receiver)` or `mint(shares, receiver)`: user sends the underlying asset to the vault, receives share tokens; the vault deposits the assets into the active strategy.
- **Withdraw** – `withdraw(assets, receiver, owner)` or `redeem(shares, receiver, owner)`: user burns shares and receives the underlying asset; the vault withdraws from the active strategy if idle balance is insufficient.
- **Aggregators** – `depositReceived(receiver, minShares, deadline)` supports a flow where the user (or router) transfers the asset to the vault and then calls this; the vault mints shares for the received amount (with slippage and deadline checks).

## Admin and strategy management

- **Owner** – Can initialize the vault once, add/remove strategies, set strategy config (enabled, targetBps, maxBps), and set the active strategy.
- **Rebalance** – Callable by anyone; only executes when a better strategy exists and the rate improvement is at least `minSwitchBps`.

**Note:** The Aave, Compound, and Morpho strategy facets in this repo implement `IStrategyFacet` but their protocol integration (supply/withdraw/rate reads) is still pending; tests use a mock strategy.

## Layout

- **`src/`**
  - `UniYieldDiamond.sol` – diamond proxy (fallback delegates to facets).
  - `diamond/` – DiamondCut, DiamondLoupe, DiamondOwnership.
  - `vault/` – VaultCoreFacet (ERC-20 + ERC-4626), StrategyRegistryFacet, RebalanceFacet.
  - `strategies/` – Aave, Compound, Morpho strategy facets (implement `IStrategyFacet`).
  - `interfaces/` – IVault4626Diamond, IUniYieldDiamond, IStrategyFacet, etc.
  - `libraries/` – LibDiamond, LibVaultStorage, LibErrors.
- **`script/`** – DeployDiamond, DeployStrategy, InitVault. See [script/README.md](script/README.md).
- **`abi/`** – Exported ABI for frontend. See [abi/README.md](abi/README.md).

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (forge, anvil, cast).

## Commands

### Build

```bash
forge build
```

### Test

```bash
forge test
```

With verbosity:

```bash
forge test -vvv
```

### Format

```bash
forge fmt
```

### Export ABI (for frontend)

```bash
./scripts/export-abi.sh
```

Writes `abi/UniYieldDiamond.json`. Use it with the diamond proxy address in the frontend (ethers, viem, etc.). See [abi/README.md](abi/README.md).

### Deploy

1. Deploy diamond and core facets: [script/README.md#DeployDiamond](script/README.md).
2. Optionally deploy strategy facets: [script/README.md#DeployStrategy](script/README.md).
3. Initialize vault on the diamond: [script/README.md#InitVault](script/README.md).

## Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [EIP-2535 Diamonds](https://eips.ethereum.org/EIPS/eip-2535)
- [EIP-4626 Tokenized Vaults](https://eips.ethereum.org/EIPS/eip-4626)
