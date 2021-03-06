//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../lib/UniswapV2Router02.sol";
import "../lib/Set.sol";
import "./IFlashSwap.sol";

contract FlashSwapDefault is IFlashSwap, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Set for Set.TokenSet;

    UniswapV2Router02 public router;

    mapping(uint256 => Set.TokenSet) private _sets;
    mapping(uint256 => mapping(IERC20 => uint256)) private _amounts;
    uint256 private _index;

    constructor(UniswapV2Router02 router_) {
        router = router_;
    }

    // Set the router to be used for the swap
    function setRouter(UniswapV2Router02 router_) external onlyOwner {
        router = router_;
    }

    function _bytesToAddress(bytes memory source_) internal pure returns (address addr) {
        assembly {
            addr := mload(add(source_, 0x14))
        }
    }

    // Wrapper for the swap
    function _swap(
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_
    ) internal returns (uint256) {
        address[] memory path = new address[](2);

        path[0] = address(tokenIn_);
        path[1] = address(tokenOut_);

        uint256 amountOut;
        if (path[0] == path[1]) {
            amountOut = amountIn_;
        } else {
            IERC20(path[0]).safeApprove(address(router), amountIn_);
            amountOut = router.swapExactTokensForTokens(amountIn_, 0, path, address(this), block.timestamp + 1)[1];
        }

        tokenOut_.safeTransfer(_msgSender(), amountOut);

        return amountOut;
    }

    // Wrapper for the amounts in
    function _amountsIn(
        IERC20 tokenIn_,
        uint256 minAmountOut_,
        IERC20 tokenOut_
    ) internal view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(tokenIn_);
        path[1] = address(tokenOut_);
        return router.getAmountsIn(minAmountOut_, path)[0];
    }

    // Swap the input tokens to the minimum amount of output tokens required
    function _flashSwap(
        IERC20[] memory tokenIn_,
        uint256[] memory amountIn_,
        IERC20[] memory tokenOut_,
        uint256[] memory minAmountOut_
    ) internal returns (uint256[] memory) {
        uint256 inIndex = _index++;
        uint256 finalIndex = _index++;

        Set.TokenSet storage inSet = _sets[inIndex];
        mapping(IERC20 => uint256) storage inAmounts = _amounts[inIndex];
        for (uint256 i = 0; i < tokenIn_.length; i++) {
            IERC20 token = tokenIn_[i];
            inSet.insert(token);
            inAmounts[token] = amountIn_[i];
        }

        mapping(IERC20 => uint256) storage finalAmounts = _amounts[finalIndex];

        for (uint256 i = 0; i < tokenOut_.length; i++) {
            IERC20 outToken = tokenOut_[i];
            uint256 minAmountOut = minAmountOut_[i];

            for (uint256 j = 0; j < inSet.count(); j++) {
                IERC20 inToken = inSet.keyAtIndex(j);
                uint256 amountIn = inAmounts[inToken];

                uint256 minIn = _amountsIn(inToken, minAmountOut, outToken);
                if (minIn > amountIn) {
                    uint256 out = _swap(inToken, amountIn, outToken);

                    finalAmounts[outToken] = finalAmounts[outToken].add(out);
                    inAmounts[inToken] = 0;
                    inSet.remove(inToken);

                    minAmountOut = minAmountOut.sub(out);
                } else {
                    uint256 out = _swap(inToken, minIn, outToken);

                    finalAmounts[outToken] = finalAmounts[outToken].add(out);
                    inAmounts[inToken] = inAmounts[inToken].sub(minIn);

                    break;
                }
            }
        }

        uint256[] memory amountsOut = new uint256[](tokenOut_.length);
        for (uint256 i = 0; i < tokenOut_.length; i++) {
            amountsOut[i] = finalAmounts[tokenOut_[i]];
        }

        return amountsOut;
    }

    // Callback for swapping from one asset to another and return the amount of the asset swapped out for
    function flashSwap(
        address,
        IERC20[] memory tokenIn_,
        uint256[] memory amountIn_,
        IERC20[] memory tokenOut_,
        uint256[] memory minAmountOut_,
        bytes memory data_
    ) external override returns (uint256[] memory) {
        uint256[] memory amountsOut = _flashSwap(tokenIn_, amountIn_, tokenOut_, minAmountOut_);

        // **** I want to redo flash swap so that it instead can take in assets with 0 value and just ignore them if that is the case + make swap more efficient

        address rewarded = _bytesToAddress(data_); // Payout excess collateral to specified account from the data
        for (uint256 i = 0; i < tokenIn_.length; i++) {
            IERC20 token = tokenIn_[i];
            uint256 tokenBalance = token.balanceOf(address(this));
            if (tokenBalance > 0) token.safeTransfer(rewarded, tokenBalance);
        }

        return amountsOut;
    }
}
