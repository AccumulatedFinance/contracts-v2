// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

// ERC20 interface
interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;  
    function burn(uint256 amount) external; 
    function transferOwnership(address newOwner) external;
}

// ERC20 interface
interface IERC4626 is IERC20 {
    function pricePerShare() external view returns (uint256); // Asset value per share (used in BaseLending)
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
        require(address(token).code.length != 0, "token does not exist");
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
        require(address(token).code.length != 0, "token does not exist");
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
        require(address(token).code.length != 0, "token does not exist");
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


/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// OpenZeppelin Contracts v4.4.1 (security/ReentrancyGuard.sol)

/**
 * @dev Contract module that helps prevent reentrant calls to a function.
 *
 * Inheriting from `ReentrancyGuard` will make the {nonReentrant} modifier
 * available, which can be applied to functions to make sure there are no nested
 * (reentrant) calls to them.
 *
 * Note that because there is a single `nonReentrant` guard, functions marked as
 * `nonReentrant` may not call one another. This can be worked around by making
 * those functions `private`, and then adding `external` `nonReentrant` entry
 * points to them.
 *
 * TIP: If you would like to learn more about reentrancy and alternative ways
 * to protect against it, check out our blog post
 * https://blog.openzeppelin.com/reentrancy-after-istanbul/[Reentrancy After Istanbul].
 */
abstract contract ReentrancyGuard {
    // Booleans are more expensive than uint256 or any type that takes up a full
    // word because each write operation emits an extra SLOAD to first read the
    // slot's contents, replace the bits taken up by the boolean, and then write
    // back. This is the compiler's defense against contract upgrades and
    // pointer aliasing, and it cannot be disabled.

    // The values being non-zero value makes deployment a bit more expensive,
    // but in exchange the refund on every call to nonReentrant will be lower in
    // amount. Since refunds are capped to a percentage of the total
    // transaction's gas, it is best to keep them low in cases like this one, to
    // increase the likelihood of the full refund coming into effect.
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and making it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        // On the first call to nonReentrant, _status will be _NOT_ENTERED
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        // Any calls to nonReentrant after this point will fail
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        // By storing the original value once again, a refund is triggered (see
        // https://eips.ethereum.org/EIPS/eip-2200)
        _status = _NOT_ENTERED;
    }
}

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract BaseLending is Ownable, ReentrancyGuard {
    using SafeTransferLib for IERC4626;

    string public constant VERSION = "v1.0.0";
    string public LENDING_TYPE = "base";

    IERC4626 public collateral; // ERC4626 collateral token
    uint256 public totalBorrowed; // Total native asset borrowed across all users
    uint256 public totalDepositedAsset; // Total native asset deposited by suppliers
    mapping(address => uint256) public userAssetDeposits; // User's deposited native asset (supply side)
    mapping(address => uint256) public userCollateral; // User's deposited collateral (in shares)
    mapping(address => uint256) public userBorrowed; // User's borrowed native asset amount

    uint256 public minDeposit = 1e15; // Minimum native asset deposit (0.001 units)
    uint256 public constant PRICE_PER_SHARE_DECIMALS = 18; // pricePerShare is always 18 decimals

    // Events
    event UpdateMinDeposit(uint256 _minDeposit);
    event DepositAsset(address indexed user, uint256 amount);
    event WithdrawAsset(address indexed user, uint256 amount);
    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);

    constructor(address _collateralToken) {
        collateral = IERC4626(_collateralToken);
    }

    function getVersion() public view virtual returns (string memory) {
        return string(abi.encodePacked(VERSION, ":", LENDING_TYPE));
    }

    function depositAsset() external payable nonReentrant {
        require(msg.value >= minDeposit, "BelowMinDeposit");
        userAssetDeposits[msg.sender] = userAssetDeposits[msg.sender] + msg.value;
        totalDepositedAsset = totalDepositedAsset + msg.value;
        emit DepositAsset(msg.sender, msg.value);
    }

    function withdrawAsset(uint256 amount) external nonReentrant {
        require(amount > 0, "ZeroAmount");
        require(userAssetDeposits[msg.sender] >= amount, "InsufficientDeposit");
        require(address(this).balance >= amount, "InsufficientBalance");
        userAssetDeposits[msg.sender] = userAssetDeposits[msg.sender] - amount;
        totalDepositedAsset = totalDepositedAsset - amount;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "TransferFailed");
        emit WithdrawAsset(msg.sender, amount);
    }

    function depositCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "LessThanMin");
        require(amount > 0, "ZeroAmount");
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        userCollateral[msg.sender] = userCollateral[msg.sender] + amount;
        emit DepositCollateral(msg.sender, amount);
    }

    function borrow(uint256 amount) external nonReentrant {
        require(amount > 0, "ZeroAmount");
        require(address(this).balance >= amount, "InsufficientBalance");
        uint256 collateralValue = _getCollateralValue(msg.sender);
        uint256 newBorrowed = userBorrowed[msg.sender] + amount;
        require(newBorrowed <= collateralValue, "InsufficientCollateral"); // 1:1 LTV
        userBorrowed[msg.sender] = newBorrowed;
        totalBorrowed = totalBorrowed + amount;
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "TransferFailed");
        emit Borrow(msg.sender, amount);
    }

    function repay() external payable nonReentrant {
        require(msg.value > 0, "ZeroAmount");
        uint256 debt = userBorrowed[msg.sender];
        require(debt > 0, "NoDebt");
        uint256 repayment = msg.value > debt ? debt : msg.value;
        userBorrowed[msg.sender] = debt - repayment;
        totalBorrowed = totalBorrowed - repayment;
        emit Repay(msg.sender, repayment);
        if (msg.value > repayment) {
            (bool sent, ) = msg.sender.call{value: msg.value - repayment}("");
            require(sent, "RefundFailed");
        }
    }

    function withdrawCollateral(uint256 amount) external nonReentrant {
        require(amount > 0, "LessThanMin");
        require(userCollateral[msg.sender] >= amount, "InsufficientCollateral");
        uint256 remainingCollateral = userCollateral[msg.sender] - amount;
        uint256 remainingValue = _getCollateralValueFromShares(remainingCollateral);
        require(remainingValue >= userBorrowed[msg.sender], "Undercollateralized");
        userCollateral[msg.sender] = remainingCollateral;
        collateral.safeTransfer(msg.sender, amount);
        emit WithdrawCollateral(msg.sender, amount);
    }

    // Read methods
    function getUserCollateralValue(address user) external view returns (uint256) {
        return _getCollateralValue(user);
    }

    function getMaxBorrowable(address user) external view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(user);
        return collateralValue - userBorrowed[user];
    }

    function getPoolAvailableBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getHealthFactor(address user) external view returns (uint256) {
        uint256 borrowed = userBorrowed[user];
        if (borrowed == 0) return type(uint256).max;
        uint256 collateralValue = _getCollateralValue(user);
        return (collateralValue * 10**PRICE_PER_SHARE_DECIMALS) / borrowed; // Precision factor
    }

    function previewMaxCollateralWithdrawal(address user) external view returns (uint256) {
        uint256 borrowed = userBorrowed[user];
        if (borrowed == 0) return userCollateral[user];
        uint256 collateralValue = _getCollateralValue(user);
        if (collateralValue <= borrowed) return 0;
        uint256 excessValue = collateralValue - borrowed;
        uint256 excessShares = (excessValue * 10**PRICE_PER_SHARE_DECIMALS) / collateral.pricePerShare();
        return excessShares > userCollateral[user] ? userCollateral[user] : excessShares;
    }

    function getPoolStats() external view returns (
        uint256 depositedAsset,
        uint256 borrowedAsset,
        uint256 availableAsset
    ) {
        return (totalDepositedAsset, totalBorrowed, address(this).balance);
    }

    function previewBorrow(address user) external view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(user);
        return collateralValue - userBorrowed[user];
    }

    // Helpers
    function _getCollateralValue(address user) internal view returns (uint256) {
        return _getCollateralValueFromShares(userCollateral[user]);
    }

    function _getCollateralValueFromShares(uint256 shares) internal view returns (uint256) {
        return (shares * collateral.pricePerShare()) / 10**PRICE_PER_SHARE_DECIMALS;
    }

    function updateMinDeposit(uint256 newMin) external onlyOwner {
        require(newMin > 0, "ZeroMinDeposit");
        require(newMin < type(uint128).max, "MinTooLarge");
        minDeposit = newMin;
        emit UpdateMinDeposit(newMin);
    }

    receive() external payable {}
}

// NativeLending contract accepts network coin as a borrowable asset for lending
contract NativeLending is BaseLending {

    constructor(address _collateralToken) BaseLending(_collateralToken) {
        LENDING_TYPE = "native";
    }

}