// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

/// @title Immutable state
/// @notice Getters that return immutable state of the router
interface IImmutableState {
    /// @return Returns the address of the BentoBox
    function bentoBox() external view returns (address);

    /// @return Returns the address of the Master Deployer
    function masterDeployer() external view returns (address);

    /// @return Returns the address of Wrapped Native token e.g. WETH
    function wrappedNative() external view returns (address);
}