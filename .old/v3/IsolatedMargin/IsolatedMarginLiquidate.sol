//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../lib/FractionMath.sol";
import "../FlashSwap/IFlashSwap.sol";
import "./IsolatedMarginLevel.sol";

abstract contract IsolatedMarginLiquidate is IsolatedMarginLevel {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    FractionMath.Fraction private _liquidationFeePercent;

    constructor(uint256 liquidationFeePercentNumerator_, uint256 liquidationFeePercentDenominator_) {
        _liquidationFeePercent.numerator = liquidationFeePercentNumerator_;
        _liquidationFeePercent.denominator = liquidationFeePercentDenominator_;
    }

    // Get the liquidation fee percent
    function liquidationFeePercent() external view returns (uint256, uint256) {
        return (_liquidationFeePercent.numerator, _liquidationFeePercent.denominator);
    }

    // Set the liquidation fee percent
    function setLiquidationFeePercent(uint256 liquidationFeePercentNumerator_, uint256 liquidationFeePercentDenominator_) external onlyOwner {
        _liquidationFeePercent.numerator = liquidationFeePercentNumerator_;
        _liquidationFeePercent.denominator = liquidationFeePercentDenominator_;
    }

    // Liquidate an undercollateralized account
    function liquidate(IERC20 borrowed_, address account_, IFlashSwap flashSwap_, bytes memory data_) external {
        require(underCollateralized(borrowed_, account_), "Only undercollateralized accounts may be liquidated");

        uint256 accountCollateral = collateral(borrowed_, account_);
        uint256 minAmountOut = oracle.amount(borrowed_, collateralPrice(borrowed_, account_));
        minAmountOut = _liquidationFeePercent.denominator.sub(_liquidationFeePercent.numerator).mul(minAmountOut).div(_liquidationFeePercent.denominator);

        IERC20[] memory swapTokens = collateralTokens(borrowed_, account_);
        uint256[] memory swapTokenAmounts = new uint256[](swapTokens.length);
        for (uint i = 0; i < swapTokens.length; i++) {
            swapTokenAmounts[i] = collateral(borrowed_, swapTokens[i], account_);
        }

        uint256 amountOut = _flashSwap(swapTokens, swapTokenAmounts, borrowed_, minAmountOut, flashSwap_, data_);
        pool.unclaim(borrowed_, borrowed(borrowed_, account_));
        pool.deposit(borrowed_, amountOut);

        _setInitialBorrowPrice(borrowed_, 0, account_);
        _setBorrowed(borrowed_, 0, account_);
        for (uint i = 0; i < swapTokens.length; i++) {
            _setCollateral(borrowed_, swapTokens[i], 0, account_);
        }

        emit Liquidated(account_, borrowed_, accountCollateral, _msgSender());
    }

    event Liquidated(address indexed account, IERC20 borrowed, uint256 amount, address liquidator);
}