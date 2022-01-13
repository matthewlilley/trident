// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

import "./IImmutableState.sol";

abstract contract ImmutableState is IImmutableState {
    /// @inheritdoc IImmutableState
    address public immutable override bentoBox;
    
    /// @inheritdoc IImmutableState
    address public immutable override masterDeployer;

    /// @inheritdoc IImmutableState
    address public immutable override wrappedNative;

    constructor(address _bentoBox, address _masterDeployer, address _wrappedNative) {
        bentoBox = _bentoBox;
        masterDeployer = _masterDeployer;
        wrappedNative = _wrappedNative;
    }
}