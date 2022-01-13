// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

import "../libraries/Cast.sol";
import "../libraries/Rebase.sol";

contract RebasingMock {

    using Cast for uint256;
    using Rebase for Total;

    Total public total;

    function toBase(uint256  elastic) public view returns (uint256 base) {
        base =  total.toBase(elastic);
    }

    function toElastic(uint256 base) public view returns (uint256 elastic) {
        elastic = total.toElastic(base);
    }

    function set(uint256 elastic, uint256 base) public {
        total.elastic = elastic.toUint128();
        total.base = base.toUint128();
    }
    function reset() public {
        total.elastic = 0;
        total.base = 0;
    }
}
