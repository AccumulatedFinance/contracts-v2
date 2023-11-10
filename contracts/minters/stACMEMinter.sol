// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

// ERC20 interface
interface IERC20 {
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function transferOwnership(address newOwner) external;
}

// WACME bridge interface
interface IWACMEBridge {
    function burn(address token, string memory account, uint256 amount) external;
}

/// @notice Safe ETH and ERC20 transfer library that gracefully handles missing return values.
/// @author Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
/// @dev Use with caution! Some functions in this library knowingly create dirty bits at the destination of the free memory pointer.
/// @dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller.
library SafeTransferLib {
    /*//////////////////////////////////////////////////////////////
                             ETH OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }

    /*//////////////////////////////////////////////////////////////
                            ERC20 OPERATIONS
    //////////////////////////////////////////////////////////////*/

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x23b872dd00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), from) // Append the "from" argument.
            mstore(add(freeMemoryPointer, 36), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 68), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 100 because the length of our calldata totals up like so: 4 + 32 * 3.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 100, 0, 32)
            )
        }

        require(success, "TRANSFER_FROM_FAILED");
    }

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0xa9059cbb00000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "TRANSFER_FAILED");
    }

    function safeApprove(
        IERC20 token,
        address to,
        uint256 amount
    ) internal {
        bool success;

        assembly {
            // Get a pointer to some free memory.
            let freeMemoryPointer := mload(0x40)

            // Write the abi-encoded calldata into memory, beginning with the function selector.
            mstore(freeMemoryPointer, 0x095ea7b300000000000000000000000000000000000000000000000000000000)
            mstore(add(freeMemoryPointer, 4), to) // Append the "to" argument.
            mstore(add(freeMemoryPointer, 36), amount) // Append the "amount" argument.

            success := and(
                // Set success to whether the call reverted, if not we check it either
                // returned exactly 1 (can't just be non-zero data), or had no return data.
                or(and(eq(mload(0), 1), gt(returndatasize(), 31)), iszero(returndatasize())),
                // We use 68 because the length of our calldata totals up like so: 4 + 32 * 2.
                // We use 0 and 32 to copy up to 32 bytes of return data into the scratch space.
                // Counterintuitively, this call must be positioned second to the or() call in the
                // surrounding and() call or else returndatasize() will be zero during the computation.
                call(gas(), token, 0, freeMemoryPointer, 68, 0, 32)
            )
        }

        require(success, "APPROVE_FAILED");
    }
}

// Ownable contract (you need to provide the Ownable contract implementation)
abstract contract Ownable {
    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }
}

contract stACMEMinter is Ownable {

    using SafeTransferLib for IERC20;

    // Base token
    IERC20 public baseToken;

    // Staking token
    IERC20 public stakingToken;

    // External bridge contract
    IWACMEBridge public bridge;

    // Staking account on Accumulate
    string public stakingAccount;

    constructor(address _baseToken, address _stakingToken, address _bridge, string memory _stakingAccount) {
        baseToken = IERC20(_baseToken);
        stakingToken = IERC20(_stakingToken);
        bridge = IWACMEBridge(_bridge);
        stakingAccount = _stakingAccount;
        // bridge can spend baseToken
        baseToken.approve(_bridge, type(uint256).max);
    }

    event TransferStakingTokenOwnership(address indexed _newOwner);
    event UpdateStakingAccount(string _stakingAccount);
    event Mint(address indexed to, uint256 amount);
    event Deposit(address indexed from, uint256 amount);

    function transferStakingTokenOwnership(address newOwner) public onlyOwner {
        stakingToken.transferOwnership(newOwner);
        emit TransferStakingTokenOwnership(newOwner);
    }

    function updateStakingAccount(string memory newStakingAccount) public onlyOwner {
        stakingAccount = newStakingAccount;
        emit UpdateStakingAccount(newStakingAccount);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        stakingToken.mint(to, amount);
        emit Mint(to, amount);
    }

    function deposit(uint256 amount) public {
        // no need reentrancyGuard because of using safeTransferFrom
        baseToken.safeTransferFrom(address(msg.sender), address(this), amount);
        
        // send users tokens to the bridge
        bridge.burn(address(baseToken), stakingAccount, amount);

        // mint staking token
        mint(address(msg.sender), amount);
        
        emit Deposit(address(msg.sender), amount);
    }

}