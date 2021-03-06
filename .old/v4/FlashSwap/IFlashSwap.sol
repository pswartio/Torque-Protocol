//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IFlashSwap {
    // Callback for swapping from one asset to another and return the amounts of the assets swapped out for
    function flashSwap(
        address initiator_,
        IERC20[] calldata tokenIn_,
        uint256[] calldata amountIn_,
        IERC20[] calldata tokenOut_,
        uint256[] calldata minAmountOut_,
        bytes calldata data_
    ) external returns (uint256[] memory amountOut_);
}
