//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IsoMarginAccount.sol";

abstract contract IsoMarginBorrow is IsoMarginAccount {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // **** Have the borrowing requirements in here with the collateral
}