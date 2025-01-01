// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.18;

import {AccessControlUpgradeable} from "@openzeppelin-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ICurvePool} from "./interfaces/ICurvePool.sol";
import {IChainlinkOracle} from "./interfaces/IChainlinkOracle.sol";
import {IStrategyInterface} from "./interfaces/IStrategyInterface.sol";

// @todo -- docs
// @todo -- constructor sanity checks 
contract Connector is AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    uint256 public immutable INDEX_ASSET_A;
    uint256 public immutable INDEX_ASSET_B;

    address public immutable VAULT;

    ICurvePool public immutable LP;
    IChainlinkOracle public immutable ORACLE;
    IStrategyInterface public immutable STRATEGY;

    IERC20 public immutable ASSET_A;
    IERC20 public immutable ASSET_B;

    bytes32 public constant VAULT_ROLE = keccak256("VAULT");

    constructor(address _vault, address _oracle, address _strategy, address _assetA, address _assetB) {
        _disableInitializers();

        VAULT = _vault;
        ORACLE = IChainlinkOracle(_oracle);
        STRATEGY = IStrategyInterface(_strategy);
        ASSET_A = IERC20(_assetA);
        ASSET_B = IERC20(_assetB);
        LP = ICurvePool(STRATEGY.asset());

        if (LP.coins(0) == _assetA) {
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

        ASSET_A.forceApprove(address(LP), type(uint256).max);
        ASSET_B.forceApprove(address(LP), type(uint256).max);
        IERC20(address(LP)).forceApprove(address(STRATEGY), type(uint256).max);
    }

    // @notice we assume the oracle is working as expected - no rate/liveness checks
    function rate() external view returns (uint256) {
        return uint256(ORACLE.latestAnswer());
    }

    function deposit(uint256 _amountA, uint256 _amountB, uint256 _minOut) external onlyRole(VAULT_ROLE) returns (uint256) {
        require(_amountA > 0 || _amountB > 0, "!amount");

        if (_amountA > 0) ASSET_A.safeTransferFrom(msg.sender, address(this), _amountA);
        if (_amountB > 0) ASSET_B.safeTransferFrom(msg.sender, address(this), _amountB);

        uint256[2] memory _amounts;
        _amounts[INDEX_ASSET_A] = _amountA;
        _amounts[INDEX_ASSET_B] = _amountB;
        LP.add_liquidity(_amounts, _minOut);

        return STRATEGY.deposit(LP.balanceOf(address(this)), msg.sender);
    }

    function withdraw(uint256 _amount, uint256 _minAmountA, uint256 _minAmountB) external onlyRole(VAULT_ROLE) returns (uint256[2] memory) {
        require(_amount > 0, "!amount");

        STRATEGY.redeem(_amount, address(this), VAULT, 0);

        uint256[2] memory _minAmounts;
        _minAmounts[INDEX_ASSET_A] = _minAmountA;
        _minAmounts[INDEX_ASSET_B] = _minAmountB;

        return LP.remove_liquidity(LP.balanceOf(address(this)), _minAmounts, msg.sender);
    }

    // @todo -- how we want this to look?
    // function sweep(address _token) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     IERC20(_token).safeTransfer(VAULT, IERC20(_token).balanceOf(address(this)));
    // }
}