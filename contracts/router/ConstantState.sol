// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

abstract contract ConstantState {
   /// @notice The user should use 0x0 if they want to deposit ETH
    address internal constant USE_ETHEREUM = address(0);
}