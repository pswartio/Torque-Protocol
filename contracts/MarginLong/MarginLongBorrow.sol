//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../Margin/Margin.sol";

abstract contract MarginLongBorrow is Margin {
    using SafeMath for uint256;

    // Margin borrow against collateral
    function borrow(IERC20 borrowed_, uint256 amount_) external onlyApprovedBorrow(borrowed_) {
        require(sufficientCollateralPrice(_msgSender()), "Insufficient collateral to borrow against");

        if (!isBorrowing(borrowed_, _msgSender())) {
            _setInitialBorrowBlock(borrowed_, block.number, _msgSender());
            _addAccount(_msgSender());
        }

        pool.claim(borrowed_, amount_);
        _setBorrowed(borrowed_, borrowed(borrowed_, _msgSender()).add(amount_), _msgSender());

        uint256 _initialBorrowPrice = oracle.priceMin(borrowed_, amount_);
        _setInitialBorrowPrice(borrowed_, initialBorrowPrice(borrowed_, _msgSender()).add(_initialBorrowPrice), _msgSender());

        require(!maxLeverageReached(_msgSender()) && !liquidatable(_msgSender()), "Borrowing desired amount puts account at risk");

        emit Borrow(_msgSender(), borrowed_, amount_);
    }

    event Borrow(address indexed account, IERC20 borrowed, uint256 amount);
}
