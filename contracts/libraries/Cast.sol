// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

library Cast {
    function toUint160(uint256 y) internal pure returns (uint160 z) {
        require((z = uint160(y)) == y);
    }

    function toUint128(uint256 y) internal pure returns (uint128 z) {
        require((z = uint128(y)) == y);
    }
}
