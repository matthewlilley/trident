// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

import "../pool/constant-product/ConstantProduct.sol";

contract TridentMathMock {
    function sqrt(uint256 x) public pure returns (uint256) {
        return ConstantProduct.sqrt(x);
    }
}
