# UniYield Core

ERC-4626 vault built as an EIP-2535 Diamond. One diamond address exposes vault (deposit/withdraw, ERC-20 shares), strategy registry, rebalance, and diamond loupe/ownership. Strategies (Aave, Compound, Morpho) are separate facet contracts; the vault delegatecalls into the active strategy.

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
