// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.23;

import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurvePool} from "./interfaces/ICurvePool.sol";
import {IChainlinkOracle} from "./interfaces/IChainlinkOracle.sol";
import {IYearnV2Vault} from "./interfaces/IYearnV2Vault.sol";

/// @title ynMaxVault <--> Curve LP <--> ERC4626 Strategy Connector
/// @dev This contract is only suitable for Curve pools with 2 assets
/// @notice Connects the ynMaxVault with a ERC4626 Strategy that accepts Curve LP tokens
contract Connector is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    error ZeroAmount();
    error ZeroAddress();

    uint256 public immutable INDEX_ASSET_A;
    uint256 public immutable INDEX_ASSET_B;

    address public immutable VAULT;

    ICurvePool public immutable CURVE_POOL;
    IChainlinkOracle public immutable ORACLE;
    IYearnV2Vault public immutable STRATEGY;

    IERC20 public immutable ASSET_A;
    IERC20 public immutable ASSET_B;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT");

    constructor(address _vault, address _oracle, address _strategy, address _assetA, address _assetB) {
        _disableInitializers();

        VAULT = _vault;
        ORACLE = IChainlinkOracle(_oracle);
        STRATEGY = IYearnV2Vault(_strategy);
        ASSET_A = IERC20(_assetA);
        ASSET_B = IERC20(_assetB);
        CURVE_POOL = ICurvePool(STRATEGY.token());

        if (CURVE_POOL.coins(0) == _assetA) {
            INDEX_ASSET_A = 0;
            INDEX_ASSET_B = 1;
        } else {
            INDEX_ASSET_A = 1;
            INDEX_ASSET_B = 0;
        }
    }

    function initialize(address admin) public initializer {
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(VAULT_ROLE, VAULT);

        ASSET_A.forceApprove(address(CURVE_POOL), type(uint256).max);
        ASSET_B.forceApprove(address(CURVE_POOL), type(uint256).max);
        IERC20(address(CURVE_POOL)).forceApprove(address(STRATEGY), type(uint256).max);
    }

    /// @notice Get the latest rate of the Strategy share token
    /// @dev We assume the oracle is working as expected. Rate/liveness checks should be done in the vault
    /// @return rate The latest rate from the oracle
    /// @return updatedAt The timestamp of the last update
    function rate() external view returns (int256, uint256) {
        (, int256 _rate, uint256 _updatedAt,,) = ORACLE.latestRoundData();
        return (_rate, _updatedAt);
    }

    /// @notice Deposit assets into the Strategy
    /// @param _amountA The amount of asset A to deposit
    /// @param _amountB The amount of asset B to deposit
    /// @param _minOut The minimum amount of LP tokens to receive
    /// @return The amount of Strategy share tokens minted
    function deposit(uint256 _amountA, uint256 _amountB, uint256 _minOut)
        external
        onlyRole(VAULT_ROLE)
        returns (uint256)
    {
        if (_amountA == 0 && _amountB == 0) revert ZeroAmount();

        if (_amountA > 0) ASSET_A.safeTransferFrom(VAULT, address(this), _amountA);
        if (_amountB > 0) ASSET_B.safeTransferFrom(VAULT, address(this), _amountB);

        uint256[] memory _amounts = new uint256[](2);
        _amounts[INDEX_ASSET_A] = _amountA;
        _amounts[INDEX_ASSET_B] = _amountB;
        CURVE_POOL.add_liquidity(_amounts, _minOut);

        uint256 _balance = CURVE_POOL.balanceOf(address(this));
        if (_balance == 0) revert ZeroAmount();

        return STRATEGY.deposit(_balance, VAULT);
    }

    /// @notice Withdraw assets from the Strategy
    /// @param _amount The amount of Strategy share tokens to redeem
    /// @param _minAmountA The minimum amount of asset A to receive
    /// @param _minAmountB The minimum amount of asset B to receive
    /// @return The amounts of asset A and B received
    function withdraw(uint256 _amount, uint256 _minAmountA, uint256 _minAmountB)
        external
        onlyRole(VAULT_ROLE)
        returns (uint256[2] memory)
    {
        if (_amount == 0) revert ZeroAmount();

        IERC20(address(STRATEGY)).transferFrom(VAULT, address(this), _amount);
        STRATEGY.withdraw(_amount, address(this));

        uint256 _balance = CURVE_POOL.balanceOf(address(this));
        if (_balance == 0) revert ZeroAmount();

        uint256[] memory _minAmounts = new uint256[](2);
        _minAmounts[INDEX_ASSET_A] = _minAmountA;
        _minAmounts[INDEX_ASSET_B] = _minAmountB;

        return CURVE_POOL.remove_liquidity(_balance, _minAmounts, VAULT);
    }

    /// @notice Sweep any ERC20 token from the contract
    /// @dev Once execution is done, this contract should not hold any tokens
    /// @param _token The address of the token to sweep
    /// @param _to The address to send the tokens to
    function sweep(address _token, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (_to == address(0)) revert ZeroAddress();
        uint256 _balance = IERC20(_token).balanceOf(address(this));
        if (_balance == 0) revert ZeroAmount();
        IERC20(_token).safeTransfer(_to, _balance);
    }
}
