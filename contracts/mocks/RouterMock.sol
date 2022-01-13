// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "../router/Router.sol";

contract RouterMock is Router {
    constructor(
        address _bentoBox,
        address _masterDeployer,
        address _wrappedNative
    ) Router(_bentoBox, _masterDeployer, _wrappedNative) {
        //
    }
}
