# UniYield Diamond ABI

Use these ABIs in the frontend to interact with the deployed UniYield Diamond.

## Files

- **UniYieldDiamond.json** – Full diamond surface: vault (ERC-20, ERC-4626), strategy registry, rebalance, diamond loupe, ownership, and diamond cut. Use this with the diamond proxy address.

## Regenerating

From repo root:

```bash
./scripts/export-abi.sh
```

Or after `forge build`:

```bash
forge inspect IUniYieldDiamond abi --json > abi/UniYieldDiamond.json
```

## Frontend usage

- **vite / webpack**: Import the JSON and pass to `new ethers.Contract(diamondAddress, abi, signer)` (or viem `getContract`).
- **Next.js**: Same; ensure the JSON is in a path that gets bundled or copy it into the frontend repo.

The diamond implements `IUniYieldDiamond`; all listed functions are callable on the single diamond address.
