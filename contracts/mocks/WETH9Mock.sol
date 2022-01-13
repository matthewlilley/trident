// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

import "./ERC20Mock.sol";

contract WETH9 is ERC20Mock {
    constructor() ERC20Mock("WETH9", "WETH9", type(uint256).max) {
        //
    }
}
