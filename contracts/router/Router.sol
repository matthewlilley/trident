// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity >=0.8.0;

import "../abstract/Batch.sol";
import "../abstract/TridentPermit.sol";
import "../deployer/IMasterDeployer.sol";
import "../interfaces/IBentoBoxV1.sol";
import "../libraries/Transfer.sol";
import "../pool/IPool.sol";

import "./ConstantState.sol";
import "./ImmutableState.sol";
import "./IRouter.sol";

// Custom Errors
error TooLittleReceived();
error NotEnoughLiquidityMinted();
error IncorrectTokenWithdrawn();
error UnauthorizedCallback();
error InsufficientWETH();
error InvalidPool();
error NotWrappedNative();

/// @notice Router contract that helps in swapping across Trident pools.
contract Router is 
    IRouter,
    ImmutableState,
    ConstantState,
    Batch,
    TridentPermit
{
    /// @dev Used to ensure that `tridentSwapCallback` is called only by the authorized address.
    /// These are set when someone calls a flash swap and reset afterwards.
    address internal cachedMsgSender;
    address internal cachedPool;

    mapping(address => bool) internal whitelistedPools;

    constructor(
        address _bentoBox,
        address _masterDeployer,
        address _wrappedNative
    ) ImmutableState(_bentoBox, _masterDeployer, _wrappedNative) {
        IBentoBoxV1(_bentoBox).registerProtocol();
    }

    receive() external payable {
        if (msg.sender != wrappedNative) revert NotWrappedNative();
    }

    /// @notice Swaps token A to token B directly. Swaps are done on `bento` tokens.
    /// @param params This includes the address of token A, pool, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pool for the swap.
    /// @dev Ensure that the pool is trusted before calling this function. The pool can steal users' tokens.
    function exactInputSingle(ExactInputSingleParams calldata params) public payable returns (uint256 amountOut) {
        // @dev Prefund the pool with token A.
        IBentoBoxV1(bentoBox).transfer(params.tokenIn, msg.sender, params.pool, params.amountIn);
        // @dev Trigger the swap in the pool.
        amountOut = IPool(params.pool).swap(params.data);
        // @dev Ensure that the slippage wasn't too much. This assumes that the pool is honest.
        if (amountOut < params.amountOutMinimum) revert TooLittleReceived();
    }

    /// @notice Swaps token A to token B indirectly by using multiple hops.
    /// @param params This includes the addresses of the tokens, pools, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pools for the swaps.
    /// @dev Ensure that the pools are trusted before calling this function. The pools can steal users' tokens.
    function exactInput(ExactInputParams calldata params) public payable returns (uint256 amountOut) {
        // @dev Pay the first pool directly.
        IBentoBoxV1(bentoBox).transfer(params.tokenIn, msg.sender, params.path[0].pool, params.amountIn);
        // @dev Call every pool in the path.
        // Pool `N` should transfer its output tokens to pool `N+1` directly.
        // The last pool should transfer its output tokens to the user.
        // If the user wants to unwrap `wETH`, the final destination should be this contract and
        // a batch call should be made to `unwrapWETH`.
        for (uint256 i; i < params.path.length; i++) {
            // We don't necessarily need this check but saving users from themselves.
            isWhiteListed(params.path[i].pool);
            amountOut = IPool(params.path[i].pool).swap(params.path[i].data);
        }
        // @dev Ensure that the slippage wasn't too much. This assumes that the pool is honest.
        if (amountOut < params.amountOutMinimum) revert TooLittleReceived();
    }

    /// @notice Swaps token A to token B directly. It's the same as `exactInputSingle` except
    /// it takes raw ERC-20 tokens from the users and deposits them into `bento`.
    /// @param params This includes the address of token A, pool, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pool for the swap.
    /// @dev Ensure that the pool is trusted before calling this function. The pool can steal users' tokens.
    function exactInputSingleWithNativeToken(ExactInputSingleParams calldata params) public payable returns (uint256 amountOut) {
        // @dev Deposits the native ERC-20 token from the user into the pool's `bento`.
        deposit(params.tokenIn, params.pool, params.amountIn);
        // @dev Trigger the swap in the pool.
        amountOut = IPool(params.pool).swap(params.data);
        // @dev Ensure that the slippage wasn't too much. This assumes that the pool is honest.
        if (amountOut < params.amountOutMinimum) revert TooLittleReceived();
    }

    /// @notice Swaps token A to token B indirectly by using multiple hops. It's the same as `exactInput` except
    /// it takes raw ERC-20 tokens from the users and deposits them into `bento`.
    /// @param params This includes the addresses of the tokens, pools, amount of token A to swap,
    /// minimum amount of token B after the swap and data required by the pools for the swaps.
    /// @dev Ensure that the pools are trusted before calling this function. The pools can steal users' tokens.
    function exactInputWithNativeToken(ExactInputParams calldata params) public payable returns (uint256 amountOut) {
        // @dev Deposits the native ERC-20 token from the user into the pool's `bento`.
        deposit(params.tokenIn, params.path[0].pool, params.amountIn);
        // @dev Call every pool in the path.
        // Pool `N` should transfer its output tokens to pool `N+1` directly.
        // The last pool should transfer its output tokens to the user.
        for (uint256 i; i < params.path.length; i++) {
            isWhiteListed(params.path[i].pool);
            amountOut = IPool(params.path[i].pool).swap(params.path[i].data);
        }
        // @dev Ensure that the slippage wasn't too much. This assumes that the pool is honest.
        if (amountOut < params.amountOutMinimum) revert TooLittleReceived();
    }

    /// @notice Swaps multiple input tokens to multiple output tokens using multiple paths, in different percentages.
    /// For example, you can swap 50 DAI + 100 USDC into 60% ETH and 40% BTC.
    /// @param params This includes everything needed for the swap. Look at the `ComplexPathParams` struct for more details.
    /// @dev This function is not optimized for single swaps and should only be used in complex cases where
    /// the amounts are large enough that minimizing slippage by using multiple paths is worth the extra gas.
    function complexPath(ComplexPathParams calldata params) public payable {
        // @dev Deposit all initial tokens to respective pools and initiate the swaps.
        // Input tokens come from the user - output goes to following pools.
        for (uint256 i; i < params.initialPath.length; i++) {
            if (params.initialPath[i].native) {
                deposit(params.initialPath[i].tokenIn, params.initialPath[i].pool, params.initialPath[i].amount);
            } else {
                IBentoBoxV1(bentoBox).transfer(params.initialPath[i].tokenIn, msg.sender, params.initialPath[i].pool, params.initialPath[i].amount);
            }
            isWhiteListed(params.initialPath[i].pool);
            IPool(params.initialPath[i].pool).swap(params.initialPath[i].data);
        }
        // @dev Do all the middle swaps. Input comes from previous pools - output goes to following pools.
        for (uint256 i; i < params.percentagePath.length; i++) {
            uint256 balanceShares = IBentoBoxV1(bentoBox).balanceOf(params.percentagePath[i].tokenIn, address(this));
            uint256 transferShares = (balanceShares * params.percentagePath[i].balancePercentage) / uint256(10)**8;
            IBentoBoxV1(bentoBox).transfer(params.percentagePath[i].tokenIn, address(this), params.percentagePath[i].pool, transferShares);
            isWhiteListed(params.percentagePath[i].pool);
            IPool(params.percentagePath[i].pool).swap(params.percentagePath[i].data);
        }
        // @dev Do all the final swaps. Input comes from previous pools - output goes to the user.
        for (uint256 i; i < params.output.length; i++) {
            uint256 balanceShares = IBentoBoxV1(bentoBox).balanceOf(params.output[i].token, address(this));
            if (balanceShares < params.output[i].minAmount) revert TooLittleReceived();
            if (params.output[i].unwrapBento) {
                IBentoBoxV1(bentoBox).withdraw(params.output[i].token, address(this), params.output[i].to, 0, balanceShares);
            } else {
                IBentoBoxV1(bentoBox).transfer(params.output[i].token, address(this), params.output[i].to, balanceShares);
            }
        }
    }

    /// @notice Add liquidity to a pool.
    /// @param tokenInput Token address and amount to add as liquidity.
    /// @param pool Pool address to add liquidity to.
    /// @param minLiquidity Minimum output liquidity - caps slippage.
    /// @param data Data required by the pool to add liquidity.
    function addLiquidity(
        TokenInput[] memory tokenInput,
        address pool,
        uint256 minLiquidity,
        bytes calldata data
    ) public payable returns (uint256 liquidity) {
        isWhiteListed(pool);
        // @dev Send all input tokens to the pool.
        for (uint256 i; i < tokenInput.length; i++) {
            if (tokenInput[i].native) {
                deposit(tokenInput[i].token, pool, tokenInput[i].amount);
            } else {
                IBentoBoxV1(bentoBox).transfer(tokenInput[i].token, msg.sender, pool, tokenInput[i].amount);
            }
        }
        liquidity = IPool(pool).mint(data);
        if (liquidity < minLiquidity) revert NotEnoughLiquidityMinted();
    }

    /// @notice Burn liquidity tokens to get back `bento` tokens.
    /// @param pool Pool address.
    /// @param liquidity Amount of liquidity tokens to burn.
    /// @param data Data required by the pool to burn liquidity.
    /// @param minWithdrawals Minimum amount of `bento` tokens to be returned.
    function burnLiquidity(
        address pool,
        uint256 liquidity,
        bytes calldata data,
        IPool.TokenAmount[] memory minWithdrawals
    ) public {
        isWhiteListed(pool);
        Transfer.safeTransferFrom(pool, msg.sender, pool, liquidity);
        IPool.TokenAmount[] memory withdrawnLiquidity = IPool(pool).burn(data);
        for (uint256 i; i < minWithdrawals.length; i++) {
            uint256 j;
            for (; j < withdrawnLiquidity.length; j++) {
                if (withdrawnLiquidity[j].token == minWithdrawals[i].token) {
                    if (withdrawnLiquidity[j].amount < minWithdrawals[i].amount) revert TooLittleReceived();
                    break;
                }
            }
            // @dev A token that is present in `minWithdrawals` is missing from `withdrawnLiquidity`.
            if (j >= withdrawnLiquidity.length) revert IncorrectTokenWithdrawn();
        }
    }

    /// @notice Burn liquidity tokens to get back `bento` tokens.
    /// @dev The tokens are swapped automatically and the output is in a single token.
    /// @param pool Pool address.
    /// @param liquidity Amount of liquidity tokens to burn.
    /// @param data Data required by the pool to burn liquidity.
    /// @param minWithdrawal Minimum amount of tokens to be returned.
    function burnLiquiditySingle(
        address pool,
        uint256 liquidity,
        bytes calldata data,
        uint256 minWithdrawal
    ) public {
        isWhiteListed(pool);
        // @dev Use 'liquidity = 0' for prefunding.
        Transfer.safeTransferFrom(pool, msg.sender, pool, liquidity);
        uint256 withdrawn = IPool(pool).burnSingle(data);
        if (withdrawn < minWithdrawal) revert TooLittleReceived();
    }

    /// @notice Used by the pool 'flashSwap' functionality to take input tokens from the user.
    function tridentSwapCallback(bytes calldata data) external {
        if (msg.sender != cachedPool) revert UnauthorizedCallback();
        TokenInput memory tokenInput = abi.decode(data, (TokenInput));
        // @dev Transfer the requested tokens to the pool.
        // TODO: Refactor redudency
        if (tokenInput.native) {
            deposit(tokenInput.token, cachedMsgSender, msg.sender, tokenInput.amount);
        } else {
            IBentoBoxV1(bentoBox).transfer(tokenInput.token, cachedMsgSender, msg.sender, tokenInput.amount);
        }
        // @dev Resets the `msg.sender`'s authorization.
        cachedMsgSender = address(1);
    }

    function isWhiteListed(address pool) internal {
        if (!whitelistedPools[pool]) {
            if (!IMasterDeployer(masterDeployer).pools(pool)) revert InvalidPool();
            whitelistedPools[pool] = true;
        }
    }

    /// @notice Deposit from msg.sender into BentoBox.
    /// @dev Amount is the native token amount. We let BentoBox do the conversion into shares.
    function deposit(
        address token,
        address recipient,
        uint256 amount
    ) internal {
        IBentoBoxV1(bentoBox).deposit{value: token == USE_ETHEREUM ? amount : 0}(token, msg.sender, recipient, amount, 0);
    }

    /// @notice Deposit from a specified sender into BentoBox.
    /// @dev Amount is the native token amount. We let BentoBox do the conversion into shares.
    function deposit(
        address token,
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        IBentoBoxV1(bentoBox).deposit{value: token == USE_ETHEREUM ? amount : 0}(token, sender, recipient, amount, 0);
    }

    /// @notice Recover mistakenly sent currency.
    function sweep(
        address token,
        uint256 amount,
        address recipient,
        bool toBento
    ) external payable {
        if (toBento) {
            IBentoBoxV1(bentoBox).transfer(token, address(this), recipient, amount);
        } else {
            token == USE_ETHEREUM ? Transfer.safeTransferNative(msg.sender, address(this).balance) : Transfer.safeTransfer(token, recipient, amount);
        }
    }

    /// @notice Provides low-level `wETH` {withdraw}.
    /// @param amount Token amount to unwrap into ETH.
    function withdrawFromWETH(uint256 amount) internal {
        (bool success, ) = wrappedNative.call(abi.encodeWithSelector(0x2e1a7d4d, amount)); // @dev withdraw(uint256).
        require(success, "WITHDRAW_FROM_WETH_FAILED");
    }

    /// @notice Recover mistakenly sent ETH.
    function refundETH() external payable {
        if (address(this).balance != 0) Transfer.safeTransferNative(msg.sender, address(this).balance);
    }

    /// @notice Provides gas-optimized balance check on this contract to avoid redundant extcodesize check in addition to returndatasize check.
    /// @param token Address of ERC-20 token.
    /// @return balance Token amount held by this contract.
    function balanceOfThis(address token) internal view returns (uint256 balance) {
        (bool success, bytes memory data) = token.staticcall(abi.encodeWithSelector(0x70a08231, address(this))); // @dev balanceOf(address).
        require(success && data.length >= 32, "BALANCE_OF_FAILED");
        balance = abi.decode(data, (uint256));
    }


    /// @notice Unwrap this contract's `wETH` into ETH
    function unwrapWETH(uint256 amountMinimum, address recipient) external {
        uint256 amount = balanceOfThis(wrappedNative);
        if (amount < amountMinimum) revert InsufficientWETH();
        if (amount != 0) {
            withdrawFromWETH(amount);
            Transfer.safeTransferNative(recipient, amount);
        }
    }

   /// @notice Helper function to allow batching of Master Deployer contract pool deployment.
    function deployPool(address factory, bytes calldata deployData) external payable returns (address) {
        return IMasterDeployer(masterDeployer).deployPool(factory, deployData);
    }

    /// @notice Helper function to allow batching of BentoBox master contract approvals so the first trade can happen in one transaction.
    function approveMasterContract(
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external payable {
        IBentoBoxV1(bentoBox).setMasterContractApproval(msg.sender, address(this), true, v, r, s);
    }

    // LIBRARY FUNCTIONS
    // https://github.com/Uniswap/v2-periphery/blob/master/contracts/UniswapV2Router02.sol#L402
}
