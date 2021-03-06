//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IsoMarginMargin.sol";

abstract contract IsoMarginRepay is IsoMarginMargin {
    using SafeMath for uint256;

    // Get the accounts collateral after a repay
    function collateralAfterRepay(IERC20 collateral_, IERC20 borrowed_, address account_) public view returns (uint256) {
        uint256 _collateral = collateral(collateral_, borrowed_, account_);
        uint256 initialBorrowPrice = _initialBorrowPrice(collateral_, borrowed_, account_);
        uint256 currentBorrowPrice = marketLink.swapPrice(borrowed_, borrowed(collateral_, borrowed_, account_), collateral_);
        uint256 interest = pool.interest(borrowed_, initialBorrowPrice, _initialBorrowBlock(collateral_, borrowed_, account_));

        return _collateral.add(currentBorrowPrice).sub(initialBorrowPrice).sub(interest);
    }

    // Repay an accounts debt when the margin value is greater
    function _repayGreater(IERC20 collateral_, IERC20 borrowed_, address account_) internal {
        uint256 initialBorrowPrice = _initialBorrowPrice(collateral_, borrowed_, account_);
        uint256 currentBorrowPrice = marketLink.swapPrice(borrowed_, borrowed(collateral_, borrowed_, account_), collateral_);
        uint256 interest = pool.interest(borrowed_, initialBorrowPrice, _initialBorrowBlock(collateral_, borrowed_, account_));

        pool.unclaim(borrowed_, collateral(collateral_, borrowed_, _msgSender()));
        uint256 payoutAmount = marketLink.swapPrice(collateral_, currentBorrowPrice.sub(initialBorrowPrice).sub(interest), borrowed_);
        pool.withdraw(borrowed_, payoutAmount);
        uint256 paidOut = _swap(borrowed_, payoutAmount, collateral_);

        _setCollateral(collateral_, borrowed_, collateral(collateral_, borrowed_, account_).add(paidOut), account_);
    }

    // Repay an accounts debt when the margin value is less than
    function _repayLessOrEqual(IERC20 collateral_, IERC20 borrowed_, address account_) internal {
        uint256 initialBorrowPrice = _initialBorrowPrice(collateral_, borrowed_, account_);
        uint256 currentBorrowPrice = marketLink.swapPrice(borrowed_, borrowed(collateral_, borrowed_, account_), collateral_);
        uint256 interest = pool.interest(borrowed_, initialBorrowPrice, _initialBorrowBlock(collateral_, borrowed_, account_));

        pool.unclaim(borrowed_, collateral(collateral_, borrowed_, account_));
        uint256 repayAmount = initialBorrowPrice.add(interest).sub(currentBorrowPrice);
        uint256 swappedAmount = _swap(collateral_, repayAmount, borrowed_);
        pool.deposit(borrowed_, swappedAmount);

        _setCollateral(collateral_, borrowed_, collateral(collateral_, borrowed_, account_).sub(repayAmount), account_);
    }

    // Repay the accounts borrowed amount
    function repay(IERC20 collateral_, IERC20 borrowed_) external {
        uint256 amountBorrowed = borrowed(collateral_, borrowed_, _msgSender());
        require(amountBorrowed > 0, "Cannot repay an account that has no debt");

        uint256 afterRepayCollateral = collateralAfterRepay(collateral_, borrowed_, _msgSender());
        if (afterRepayCollateral <= collateral(collateral_, borrowed_, _msgSender())) _repayLessOrEqual(collateral_, borrowed_, _msgSender());
        else _repayGreater(collateral_, borrowed_, _msgSender());

        _setInitialBorrowPrice(collateral_, borrowed_, 0, _msgSender());
        _setBorrowed(collateral_, borrowed_, 0, _msgSender());

        emit Repay(_msgSender(), collateral_, borrowed_, afterRepayCollateral);
    }

    event Repay(address indexed account, IERC20 collateral, IERC20 borrowed, uint256 afterRepayCollateral);
}