//SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.0;

library FracExp {
    // https://ethereum.stackexchange.com/a/10432
    // Computes `k * (1+1/q) ^ N`, with precision `p`. The higher
    // the precision, the higher the gas cost. It should be
    // something around the log of `n`. When `p == n`, the
    // precision is absolute (sans possible integer overflows). <edit: NOT true, see comments>
    // Much smaller values are sufficient to get a great approximation.
    function fracExp(uint k, uint q, uint n, uint p) internal pure returns (uint) {
        uint s = 0;
        uint N = 1;
        uint B = 1;

        for (uint i = 0; i < p; ++i){
            s += k * N / B / (q**i);
            N  = N * (n-i);
            B  = B * (i+1);
        }

        return s;
    }
}