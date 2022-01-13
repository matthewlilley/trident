// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >= 0.8.0;

error ApproveFailed();

library Approve {
    /// @param token Address of ERC-20 token.
    /// @param to Target of the approval.
    /// @param value Amount the target will be allowed to spend.
    function safeApprove(
        address token,
        address to,
        uint256 value
    ) internal {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        if (!success || (data.length != 0 && !abi.decode(data, (bool)))) revert ApproveFailed();
    }
}
