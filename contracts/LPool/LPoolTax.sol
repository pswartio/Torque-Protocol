//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

import "../lib/FractionMath.sol";
import "../lib/Set.sol";
import "./LPoolCore.sol";

abstract contract LPoolTax is LPoolCore {
    using Set for Set.AddressSet;

    FractionMath.Fraction private _taxPercent;
    Set.AddressSet private _taxAccountSet;

    constructor(uint256 taxPercentNumerator_, uint256 taxPercentDenominator_) {
        _taxPercent.numerator = taxPercentNumerator_;
        _taxPercent.denominator = taxPercentDenominator_;
    }

    // Get the tax percentage
    function taxPercentage() public view returns (uint256, uint256) {
        return (_taxPercent.numerator, _taxPercent.denominator);
    }

    // Set the tax percentage
    function setTaxPercentage(uint256 taxPercentNumerator_, uint256 taxPercentDenominator_) external onlyRole(POOL_ADMIN) {
        _taxPercent.numerator = taxPercentNumerator_;
        _taxPercent.denominator = taxPercentDenominator_;
    }

    // Add a text account
    function addTaxAccount(address account_) external onlyRole(POOL_ADMIN) {
        _taxAccountSet.insert(account_);
    }

    // Remove a tax account
    function removeTaxAccount(address account_) external onlyRole(POOL_ADMIN) {
        _taxAccountSet.remove(account_);
    }

    // Get the tax accounts
    function _taxAccounts() internal view returns (address[] memory) {
        return _taxAccountSet.iterable();
    }
}
