// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {LibVaultStorage} from "../libraries/LibVaultStorage.sol";
import {LibErrors} from "../libraries/LibErrors.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibReentrancyGuard} from "../libraries/LibReentrancyGuard.sol";
import {IStrategyFacet} from "../interfaces/IStrategyFacet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VaultCoreFacet {
    using SafeERC20 for IERC20;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    event StrategyDeposited(bytes32 indexed strategyId, uint256 assets);
    event StrategyWithdrawn(bytes32 indexed strategyId, uint256 assets);
    event VaultInitialized(
        address asset, string name, string symbol, uint8 shareDecimals, uint16 minSwitchBps, bytes32 activeStrategyId
    );
    event Paused();
    event Unpaused();

    function pause() external {
        _enforceOwner();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (vs.paused) return;
        vs.paused = true;
        emit Paused();
    }

    function unpause() external {
        _enforceOwner();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (!vs.paused) return;
        vs.paused = false;
        emit Unpaused();
    }

    function initVault(
        address asset_,
        uint8 assetDecimals_,
        string calldata name_,
        string calldata symbol_,
        uint8 shareDecimals_,
        uint16 minSwitchBps_,
        bytes32 activeStrategyId_
    ) external {
        _enforceOwner();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        if (vs.asset != address(0)) revert LibErrors.AlreadyInitialized();
        if (asset_ == address(0)) revert LibErrors.ZeroAddress();
        if (minSwitchBps_ > 10_000) revert LibErrors.InvalidBps();

        vs.asset = asset_;
        vs.assetDecimals = assetDecimals_;
        vs.name = name_;
        vs.symbol = symbol_;
        vs.shareDecimals = shareDecimals_;
        vs.minSwitchBps = minSwitchBps_;
        vs.activeStrategyId = activeStrategyId_;

        emit VaultInitialized(asset_, name_, symbol_, shareDecimals_, minSwitchBps_, activeStrategyId_);
    }

    // ERC-20 metadata
    function name() external view returns (string memory) {
        return LibVaultStorage.vaultStorage().name;
    }

    function symbol() external view returns (string memory) {
        return LibVaultStorage.vaultStorage().symbol;
    }

    function decimals() external view returns (uint8) {
        return LibVaultStorage.vaultStorage().shareDecimals;
    }

    // ERC-20 surface
    function totalSupply() external view returns (uint256) {
        return LibVaultStorage.vaultStorage().totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return LibVaultStorage.vaultStorage().balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return LibVaultStorage.vaultStorage().allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        if (spender == address(0)) revert LibErrors.ZeroAddress();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        vs.allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }

    // ERC-4626 surface
    function asset() public view returns (address) {
        return LibVaultStorage.vaultStorage().asset;
    }

    function totalAssets() public view returns (uint256) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 idle = IERC20(vs.asset).balanceOf(address(this));
        uint256 managed = 0;
        bytes32 activeId = vs.activeStrategyId;
        if (activeId != bytes32(0) && _strategyExists(activeId)) {
            managed = _strategyTotalManagedAssets(activeId);
        }
        return idle + managed;
    }

    function convertToShares(uint256 assets) public view returns (uint256) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        return _previewDeposit(assets, totalAssets(), vs.totalSupply);
    }

    function convertToAssets(uint256 shares) public view returns (uint256) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        return _previewRedeem(shares, totalAssets(), vs.totalSupply);
    }

    /// @notice ERC-4626: preview shares for deposit
    function previewDeposit(uint256 assets) external view returns (uint256) {
        return _previewDeposit(assets, totalAssets(), LibVaultStorage.vaultStorage().totalSupply);
    }

    /// @notice ERC-4626: preview assets for mint
    function previewMint(uint256 shares) external view returns (uint256) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        return _previewMint(shares, totalAssets(), vs.totalSupply);
    }

    /// @notice ERC-4626: preview shares for withdraw
    function previewWithdraw(uint256 assets) external view returns (uint256) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        return _previewWithdraw(assets, totalAssets(), vs.totalSupply);
    }

    /// @notice ERC-4626: preview assets for redeem
    function previewRedeem(uint256 shares) external view returns (uint256) {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        return _previewRedeem(shares, totalAssets(), vs.totalSupply);
    }

    /// @notice ERC-4626: max deposit (no limit)
    function maxDeposit(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    /// @notice ERC-4626: max mint (no limit)
    function maxMint(address) external pure returns (uint256) {
        return type(uint256).max;
    }

    /// @notice ERC-4626: max withdraw for owner
    function maxWithdraw(address owner) external view returns (uint256) {
        return convertToAssets(LibVaultStorage.vaultStorage().balances[owner]);
    }

    /// @notice ERC-4626: max redeem for owner
    function maxRedeem(address owner) external view returns (uint256) {
        return LibVaultStorage.vaultStorage().balances[owner];
    }

    function deposit(uint256 assets, address receiver) external returns (uint256 shares) {
        LibReentrancyGuard.enter();
        _requireNotPaused();
        if (receiver == address(0)) revert LibErrors.ZeroAddress();
        if (assets == 0) revert LibErrors.ZeroAssets();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 totalAssetsBefore = totalAssets();

        IERC20(vs.asset).safeTransferFrom(msg.sender, address(this), assets);

        shares = _previewDeposit(assets, totalAssetsBefore, vs.totalSupply);
        if (shares == 0) revert LibErrors.ZeroShares();

        _mint(receiver, shares);
        _depositToActiveStrategy(assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        LibReentrancyGuard.exit();
    }

    function mint(uint256 shares, address receiver) external returns (uint256 assets) {
        LibReentrancyGuard.enter();
        _requireNotPaused();
        if (receiver == address(0)) revert LibErrors.ZeroAddress();
        if (shares == 0) revert LibErrors.ZeroShares();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 totalAssetsBefore = totalAssets();
        assets = _previewMint(shares, totalAssetsBefore, vs.totalSupply);
        if (assets == 0) revert LibErrors.ZeroAssets();

        IERC20(vs.asset).safeTransferFrom(msg.sender, address(this), assets);

        _mint(receiver, shares);
        _depositToActiveStrategy(assets);

        emit Deposit(msg.sender, receiver, assets, shares);
        LibReentrancyGuard.exit();
    }

    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares) {
        LibReentrancyGuard.enter();
        _requireNotPaused();
        if (receiver == address(0) || owner == address(0)) revert LibErrors.ZeroAddress();
        if (assets == 0) revert LibErrors.ZeroAssets();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        shares = _previewWithdraw(assets, totalAssets(), vs.totalSupply);
        if (shares == 0) revert LibErrors.ZeroShares();

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);

        uint256 idle = IERC20(vs.asset).balanceOf(address(this));
        if (idle < assets) {
            _withdrawFromActiveStrategy(assets - idle);
        }

        IERC20(vs.asset).safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        LibReentrancyGuard.exit();
    }

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets) {
        LibReentrancyGuard.enter();
        _requireNotPaused();
        if (receiver == address(0) || owner == address(0)) revert LibErrors.ZeroAddress();
        if (shares == 0) revert LibErrors.ZeroShares();

        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        assets = _previewRedeem(shares, totalAssets(), vs.totalSupply);
        if (assets == 0) revert LibErrors.ZeroAssets();

        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        _burn(owner, shares);

        uint256 idle = IERC20(vs.asset).balanceOf(address(this));
        if (idle < assets) {
            _withdrawFromActiveStrategy(assets - idle);
        }

        IERC20(vs.asset).safeTransfer(receiver, assets);
        emit Withdraw(msg.sender, receiver, owner, assets, shares);
        LibReentrancyGuard.exit();
    }

    // Internal helpers
    function _requireNotPaused() internal view {
        if (LibVaultStorage.vaultStorage().paused) revert LibErrors.Paused();
    }

    function _enforceOwner() internal view {
        if (msg.sender != LibDiamond.contractOwner()) revert LibErrors.NotAuthorized();
    }

    function _strategyFacet(bytes32 id) internal pure returns (address) {
        return address(uint160(uint256(id)));
    }

    function _strategyExists(bytes32 id) internal view returns (bool) {
        if (id == bytes32(0)) return false;
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        bytes32[] storage ids = vs.strategyIds;
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == id) return true;
        }
        return false;
    }

    function _strategyTotalManagedAssets(bytes32 id) internal view returns (uint256 managed) {
        bytes memory data = abi.encodeWithSelector(IStrategyFacet.totalManagedAssets.selector);
        bytes memory result = _staticCallStrategy(id, data);
        managed = abi.decode(result, (uint256));
    }

    function _depositToActiveStrategy(uint256 assets) internal {
        if (assets == 0) return;
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        bytes32 id = vs.activeStrategyId;
        if (!_strategyExists(id)) revert LibErrors.StrategyNotFound(id);
        if (!vs.strategies[id].enabled) revert LibErrors.StrategyDisabled(id);

        _delegateToStrategy(id, abi.encodeWithSelector(IStrategyFacet.depositToStrategy.selector, assets));
        emit StrategyDeposited(id, assets);
    }

    function _withdrawFromActiveStrategy(uint256 assets) internal {
        if (assets == 0) return;
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        bytes32 id = vs.activeStrategyId;
        if (!_strategyExists(id)) revert LibErrors.StrategyNotFound(id);

        _delegateToStrategy(id, abi.encodeWithSelector(IStrategyFacet.withdrawFromStrategy.selector, assets));
        emit StrategyWithdrawn(id, assets);
    }

    function _delegateToStrategy(bytes32 id, bytes memory data) internal returns (bytes memory result) {
        address facet = _strategyFacet(id);
        if (facet == address(0)) revert LibErrors.StrategyNotFound(id);
        (bool ok, bytes memory returndata) = facet.delegatecall(data);
        if (!ok) revert LibErrors.ExternalCallFailed(id);
        return returndata;
    }

    function _staticCallStrategy(bytes32 id, bytes memory data) internal view returns (bytes memory result) {
        address facet = _strategyFacet(id);
        if (facet == address(0)) revert LibErrors.StrategyNotFound(id);
        (bool ok, bytes memory returndata) = facet.staticcall(data);
        if (!ok) revert LibErrors.ExternalCallFailed(id);
        return returndata;
    }

    /// @dev OZ-style virtual shares/assets to mitigate ERC-4626 donation/inflation attack.
    /// shares = assets * (totalSupply + offset) / (totalAssets + 1)
    function _previewDeposit(uint256 assets, uint256 totalAssets_, uint256 totalSupply_)
        internal
        pure
        returns (uint256)
    {
        uint256 supply = totalSupply_ + LibVaultStorage.VIRTUAL_SHARES_OFFSET;
        uint256 assets_ = totalAssets_ + LibVaultStorage.VIRTUAL_ASSETS_OFFSET;
        if (assets_ == 0) return 0;
        return (assets * supply) / assets_;
    }

    function _previewMint(uint256 shares, uint256 totalAssets_, uint256 totalSupply_) internal pure returns (uint256) {
        uint256 supply = totalSupply_ + LibVaultStorage.VIRTUAL_SHARES_OFFSET;
        uint256 assets_ = totalAssets_ + LibVaultStorage.VIRTUAL_ASSETS_OFFSET;
        if (supply == 0) return 0;
        return _mulDivUp(shares, assets_, supply);
    }

    function _previewWithdraw(uint256 assets, uint256 totalAssets_, uint256 totalSupply_)
        internal
        pure
        returns (uint256)
    {
        uint256 supply = totalSupply_ + LibVaultStorage.VIRTUAL_SHARES_OFFSET;
        uint256 assets_ = totalAssets_ + LibVaultStorage.VIRTUAL_ASSETS_OFFSET;
        if (assets_ == 0) return 0;
        return _mulDivUp(assets, supply, assets_);
    }

    function _previewRedeem(uint256 shares, uint256 totalAssets_, uint256 totalSupply_)
        internal
        pure
        returns (uint256)
    {
        uint256 supply = totalSupply_ + LibVaultStorage.VIRTUAL_SHARES_OFFSET;
        uint256 assets_ = totalAssets_ + LibVaultStorage.VIRTUAL_ASSETS_OFFSET;
        if (supply == 0) return 0;
        return (shares * assets_) / supply;
    }

    function _mulDivUp(uint256 a, uint256 b, uint256 denominator) internal pure returns (uint256) {
        if (a == 0 || b == 0) return 0;
        return (a * b + denominator - 1) / denominator;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        if (to == address(0) || from == address(0)) revert LibErrors.ZeroAddress();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 fromBalance = vs.balances[from];
        if (fromBalance < amount) revert LibErrors.InsufficientBalance(fromBalance, amount);
        unchecked {
            vs.balances[from] = fromBalance - amount;
            vs.balances[to] += amount;
        }
        emit Transfer(from, to, amount);
    }

    function _spendAllowance(address owner, address spender, uint256 amount) internal {
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 currentAllowance = vs.allowances[owner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert LibErrors.InsufficientAllowance(currentAllowance, amount);
            unchecked {
                vs.allowances[owner][spender] = currentAllowance - amount;
            }
            emit Approval(owner, spender, vs.allowances[owner][spender]);
        }
    }

    function _mint(address to, uint256 amount) internal {
        if (to == address(0)) revert LibErrors.ZeroAddress();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        vs.totalSupply += amount;
        vs.balances[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function _burn(address from, uint256 amount) internal {
        if (from == address(0)) revert LibErrors.ZeroAddress();
        LibVaultStorage.VaultStorage storage vs = LibVaultStorage.vaultStorage();
        uint256 fromBalance = vs.balances[from];
        if (fromBalance < amount) revert LibErrors.InsufficientBalance(fromBalance, amount);
        unchecked {
            vs.balances[from] = fromBalance - amount;
            vs.totalSupply -= amount;
        }
        emit Transfer(from, address(0), amount);
    }
}
