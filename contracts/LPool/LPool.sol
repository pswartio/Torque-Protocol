//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../Converter/IConverter.sol";
import "./LPoolStake.sol";
import "./LPoolInterest.sol";

contract LPool is LPoolStake, LPoolInterest {
    constructor(
        IConverter converter_,
        uint256 taxPercent_,
        uint256 blocksPerCompound_
    ) LPoolTax(taxPercent_, 100) LPoolDeposit(converter_) LPoolInterest(blocksPerCompound_) {}
}
