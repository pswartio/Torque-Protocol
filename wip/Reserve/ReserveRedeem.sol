//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./ReserveApproved.sol";
import "./ReserveStakeAccount.sol";

abstract contract ReserveRedeem is ReserveApproved, ReserveStakeAccount {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Get the total tokens in reserve for a given token
    function totalReserve(IERC20 token_) public view returns (uint256) {
        uint256 staked = totalStaked(token_);
        uint256 available = token_.balanceOf(address(this)).sub(staked);
        return available;
    }

    // Get the total liquidity price of the reserve
    function totalPrice() public view returns (uint256) {
        uint256 _totalPrice = 0;

        IERC20[] memory approved = _approved();
        for (uint256 i = 0; i < approved.length; i++) {
            uint256 price = oracle.priceMin(approved[i], totalReserve(approved[i]));
            _totalPrice = _totalPrice.add(price);
        }

        return _totalPrice;
    }

    // Return the total backing price for each token
    function backingPricePerAsset() public view returns (uint256, uint256) {
        return (totalPrice(), token.totalSupply());
    }

    // Get the amount of tokens received for redeeming tokens
    function redeemValue(uint256 amount_, IERC20 token_) public view returns (uint256) {
        (uint256 backingPriceNumerator, uint256 backingPriceDenominator) = backingPricePerAsset();

        uint256 entitledPrice = amount_.mul(backingPriceNumerator).div(backingPriceDenominator);
        uint256 entitledAmount = oracle.amountMin(token_, entitledPrice);

        return entitledAmount;
    }

    // Redeem tokens for the underlying reserve asset
    function redeem(uint256 amount_, IERC20 token_) external onlyApproved(token_) returns (uint256) {
        uint256 _redeemValue = redeemValue(amount_, token_);

        token_.safeTransfer(_msgSender(), _redeemValue);
        token.burn(_msgSender(), amount_);

        emit Redeem(_msgSender(), amount_, token_, _redeemValue);

        return _redeemValue;
    }

    event Redeem(address indexed account, uint256 amount, IERC20 redeemToken, uint256 redeemValue);
}
