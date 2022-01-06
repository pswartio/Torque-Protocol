//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../FlashSwap/IFlashSwap.sol";
import "./MarginLongRepay.sol";

abstract contract MarginLongLiquidate is MarginLongRepay {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Liquidate all accounts that have not been repaid by the repay greater
    function _liquidate(
        address account_,
        IFlashSwap flashSwap_,
        bytes memory data_
    ) internal {
        IERC20[] memory collateralTokens = _collateralTokens(account_);
        uint256[] memory collateralAmounts = new uint256[](collateralTokens.length);
        for (uint256 i = 0; i < collateralTokens.length; i++) collateralAmounts[i] = collateral(collateralTokens[i], account_);

        (IERC20[] memory repayTokensOut, uint256[] memory repayAmountsOut, ) = _repayAmountsOut(account_);

        uint256[] memory amountOut = _flashSwap(collateralTokens, collateralAmounts, repayTokensOut, repayAmountsOut, flashSwap_, data_);
        for (uint256 i = 0; i < amountOut.length; i++) {
            repayTokensOut[i].safeApprove(address(pool), amountOut[i]);
            pool.deposit(repayTokensOut[i], amountOut[i]);
        }
    }

    // Liquidate an undercollateralized account
    function liquidate(
        address account_,
        IFlashSwap flashSwap_,
        bytes memory data_
    ) external {
        require(underCollateralized(account_), "Only undercollateralized accounts may be liquidated");

        _repayPayout(account_);
        _liquidate(account_, flashSwap_, data_);

        emit Liquidated(account_, _msgSender(), flashSwap_, data_);
    }

    event Liquidated(address indexed account, address liquidator, IFlashSwap flashSwap, bytes data);
}