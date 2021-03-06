// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/*
Hitchens UnorderedAddressSet v0.93
Library for managing CRUD operations in dynamic address sets.
https://github.com/rob-Hitchens/UnorderedKeySet
Copyright (c), 2019, Rob Hitchens, the MIT License
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
THIS SOFTWARE IS NOT TESTED OR AUDITED. DO NOT USE FOR PRODUCTION.
*/

library Set {
    struct TokenSet {
        mapping(IERC20 => uint256) keyPointers;
        IERC20[] keyList;
    }

    function insert(TokenSet storage self, IERC20 key) internal {
        require(!exists(self, key), "Token already exists in the set.");
        self.keyList.push(key);
        self.keyPointers[key] = self.keyList.length - 1;
    }

    function remove(TokenSet storage self, IERC20 key) internal {
        require(exists(self, key), "Token does not exist in the set.");
        IERC20 keyToMove = self.keyList[count(self) - 1];
        uint256 rowToReplace = self.keyPointers[key];

        self.keyPointers[keyToMove] = rowToReplace;
        self.keyList[rowToReplace] = keyToMove;

        delete self.keyPointers[key];
        self.keyList.pop();
    }

    function count(TokenSet storage self) internal view returns (uint256) {
        return (self.keyList.length);
    }

    function exists(TokenSet storage self, IERC20 key) internal view returns (bool) {
        if (self.keyList.length == 0) return false;
        return self.keyList[self.keyPointers[key]] == key;
    }

    function keyAtIndex(TokenSet storage self, uint256 index) internal view returns (IERC20) {
        return self.keyList[index];
    }

    function iterable(TokenSet storage self) internal view returns (IERC20[] memory) {
        return self.keyList;
    }

    struct AddressSet {
        mapping(address => uint256) keyPointers;
        address[] keyList;
    }

    function insert(AddressSet storage self, address key) internal {
        require(!exists(self, key), "Address already exists in the set.");
        self.keyList.push(key);
        self.keyPointers[key] = self.keyList.length - 1;
    }

    function remove(AddressSet storage self, address key) internal {
        require(exists(self, key), "Address does not exist in the set.");
        address keyToMove = self.keyList[count(self) - 1];
        uint256 rowToReplace = self.keyPointers[key];

        self.keyPointers[keyToMove] = rowToReplace;
        self.keyList[rowToReplace] = keyToMove;

        delete self.keyPointers[key];
        self.keyList.pop();
    }

    function count(AddressSet storage self) internal view returns (uint256) {
        return (self.keyList.length);
    }

    function exists(AddressSet storage self, address key) internal view returns (bool) {
        if (self.keyList.length == 0) return false;
        return self.keyList[self.keyPointers[key]] == key;
    }

    function keyAtIndex(AddressSet storage self, uint256 index) internal view returns (address) {
        return self.keyList[index];
    }

    function iterable(AddressSet storage self) internal view returns (address[] memory) {
        return self.keyList;
    }
}
