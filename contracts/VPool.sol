//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "./IVPool.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// **** For the moment users will have to withraw profits and restake into a new pool manually
// **** Perhaps in the future we will allow minting of a new token that will be used by the DAO - a specific amount of tokens based on supply will be allocated to each pool, and will be distributed out at the end
// **** This should be performed from the DAO itself, not from the pool directly - it will be issued by the pools functions however

contract VPool is IVPool, AccessControl {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    // Approved assets of the pool
    IERC20[] private approvedList;
    mapping(IERC20 => bool) private approved;

    // Staking data
    struct StakingPeriod {
        uint256 totalDeposited;
        uint256 liquidity;
        mapping(address => uint256) deposits;
    }
    mapping(uint256 => mapping(IERC20 => StakingPeriod)) private stakingPeriods; // Stores the data for each approved asset
    uint256 private stakingTimeframe;
    uint256 private cooldownTimeframe;

    constructor(uint256 stakingTimeframe_, uint256 cooldownTimeframe_) {
        stakingTimeframe = stakingTimeframe_;
        cooldownTimeframe = cooldownTimeframe_;
        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    // ======== Check the staking period and cooldown periods ========

    function isCooldown(uint256 _periodId) public view override returns (bool) {
        // Check if the cooldown period of the specified period is present
        uint256 periodStart = _periodId.mul(stakingTimeframe);
        uint256 cooldownEnd = periodStart + cooldownTimeframe;
        uint256 current = block.timestamp;
        return current >= periodStart && current < cooldownEnd;
    }

    function isCooldown() public view override returns (bool) {
        // Check if the cooldown period of the current period is present
        return isCooldown(currentPeriodId());
    }

    function isCurrentPeriod(uint256 _periodId) public view override returns (bool) {
        return _periodId == currentPeriodId();
    }

    function currentPeriodId() public view override returns (uint256) {
        return uint256(block.timestamp).div(stakingTimeframe);
    }

    function nextPeriodStart() public view override returns (uint256) {
        return currentPeriodId().add(1).mul(stakingTimeframe);
    }

    // ======== Approved tokens ========

    function approveToken(IERC20 _token) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // Satisfy the requirements
        require(!isApproved(_token), "This token has already been approved");

        // Approve the token
        approved[_token] = true;
        approvedList.push(_token);
    }

    function isApproved(IERC20 _token) public view override returns (bool) {
        return approved[_token];
    }

    function getApproved() external view override returns (IERC20[] memory) {
        return approvedList;
    }

    modifier approvedOnly(IERC20 _token) {
        require(isApproved(_token), "This token has not been approved");
        _;
    }

    // ======== Helper functions ========

    function getLiquidity(IERC20 _token, uint256 _periodId) external view override approvedOnly(_token) returns (uint256) {
        return stakingPeriods[_periodId][_token].liquidity;
    }

    // ======== Balance management ========

    function balanceOf(address _account, IERC20 _token, uint256 _periodId) public view override approvedOnly(_token) returns (uint256) {
        // Get the amount of tokens the account deposited into a given period
        return stakingPeriods[_periodId][_token].deposits[_account];
    }

    function balanceOf(address _account, IERC20 _token) external view override approvedOnly(_token) returns (uint256) {
        // Get the amount of tokens the account deposited into the current period
        return balanceOf(_account, _token, currentPeriodId());
    }

    function redeemValue(IERC20 _token, uint256 _periodId, uint256 _amount) public view override approvedOnly(_token) returns (uint256) {
        // Get the value for redeeming a given amount of tokens for a given periodId
        StakingPeriod storage period = stakingPeriods[_periodId][_token];

        uint256 totalDeposited = period.totalDeposited;
        uint256 liquidity = period.liquidity;

        return _amount.mul(liquidity).div(totalDeposited);
    }

    // ======== Liquidity manipulation ========

    function stake(IERC20 _token, uint256 _amount) external override approvedOnly(_token) {
        // Make sure the requirements are satisfied
        require(isCooldown() == true, "Staking is only allowed during the cooldown period");
        require(_amount > 0, "Stake amount must be greater than 0");

        // Move the tokens to the pool and update the users deposit amount
        _token.transferFrom(_msgSender(), address(this), _amount);

        uint256 periodId = currentPeriodId();
        stakingPeriods[periodId][_token].deposits[_msgSender()] = stakingPeriods[periodId][_token].deposits[_msgSender()].add(_amount);
        stakingPeriods[periodId][_token].liquidity = stakingPeriods[periodId][_token].liquidity.add(_amount);
        stakingPeriods[periodId][_token].totalDeposited = stakingPeriods[periodId][_token].totalDeposited.add(_amount);

        emit Stake(_msgSender(), _token, periodId, _amount);
    }

    function redeem(IERC20 _token, uint256 _amount, uint256 _periodId) external override approvedOnly(_token) {
        // Make sure the requirements are satisfied
        require(isCooldown(_periodId) || !isCurrentPeriod(_periodId), "Withdraw is only allowed during cooldown or once period has ended");
        require(_amount > 0, "Redeem amount must be greater than 0");
        require(_amount <= balanceOf(_msgSender(), _token, _periodId), "Cannot redeem more than total balance");

        // Update the balances of the period
        uint256 deposited = stakingPeriods[_periodId][_token].deposits[_msgSender()];
        uint256 totalDeposited = stakingPeriods[_periodId][_token].totalDeposited;
        uint256 liquidity = stakingPeriods[_periodId][_token].liquidity;

        stakingPeriods[_periodId][_token].deposits[_msgSender()] = deposited.sub(_amount);
        stakingPeriods[_periodId][_token].totalDeposited = totalDeposited.sub(_amount);

        // Withdraw the allocated amount from the pool and return it to the user
        uint256 tokensRedeemed = redeemValue(_token, _periodId, _amount);
        stakingPeriods[_periodId][_token].liquidity = liquidity.sub(tokensRedeemed);
        _token.transfer(_msgSender(), tokensRedeemed);
        emit Redeem(_msgSender(), _token, _periodId, _amount, tokensRedeemed);
    }

    function deposit(IERC20 _token, uint256 _amount) external override approvedOnly(_token) {
        // Make sure no deposits during cooldown period
        uint256 periodId = currentPeriodId();
        require(!isCooldown(periodId), "Cannot deposit on period cooldown");

        // **** If I wanted to add some sort of reward payout distributor, it would be best to do it here and then pay the remainder to the pool

        // Receive a given number of funds to the current pool
        _token.transferFrom(_msgSender(), address(this), _amount);
        stakingPeriods[periodId][_token].liquidity = stakingPeriods[periodId][_token].liquidity.add(_amount);
        emit Deposit(_token, periodId, _amount);
    }

    function withdraw(IERC20 _token, uint256 _amount, address _to) external override approvedOnly(_token) onlyRole(DEFAULT_ADMIN_ROLE) {
        // Make sure no withdraws during cooldown period
        uint256 periodId = currentPeriodId();
        require(!isCooldown(periodId), "Cannot withdraw on period cooldown");

        // Withdraw an amount from the current pool
        StakingPeriod storage stakingPeriod = stakingPeriods[periodId][_token]; 
        require(_amount <= stakingPeriod.liquidity, "Cannot withdraw more than value pool");
        stakingPeriods[periodId][_token].liquidity = stakingPeriod.liquidity.sub(_amount);
        _token.transfer(_to, _amount);
        emit Withdraw(_token, periodId, _to, _amount);
    }
}