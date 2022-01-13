// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

error TransferFailed();
error TransferFromFailed();
error TransferNativeFailed();
error ApproveFailed();

library Transfer {
    /// @param token Address of ERC-20 token.
    /// @param recipient Address of recipient.
    /// @param amount Amount to send.
    function safeTransfer(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, recipient, amount)); // @dev transfer(address,uint256)
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFailed();
    }

    /// @param token Address of ERC-20 token.
    /// @param sender Address of sender.
    /// @param recipient Address of recipient.
    /// @param amount Amount to send.
    function safeTransferFrom(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, sender, recipient, amount)); // @dev transferFrom(address,address,uint256).
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert TransferFromFailed();
    }

    /// @param recipient Address of recipient.
    /// @param amount Amount to send.
    function safeTransferNative(address recipient, uint256 amount) internal {
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) revert TransferNativeFailed();
    }
}
