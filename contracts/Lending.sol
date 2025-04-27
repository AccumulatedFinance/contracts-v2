// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;


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

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
}


/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
abstract contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * The default value of {decimals} is 18. To select a different value for
     * {decimals} you should overload it.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_, uint8 decimals_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `sender` to `recipient`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
        }
        _balances[to] += amount;

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// ERC20 interface
interface IERC4626 is IERC20Metadata {
    function pricePerShare() external view returns (uint256); // Asset value per share (used in BaseLending)
}

abstract contract BaseLending is Ownable, ReentrancyGuard, ERC20 {
    using SafeTransferLib for IERC4626;

    string public constant VERSION = "v1.0.0";
    string public LENDING_TYPE = "base";

    IERC4626 public collateral; // ERC4626 collateral token
    uint256 public totalDebtShares; // Total debt shares across all users
    uint256 public totalAssets; // Total native asset deposited by suppliers (now includes interest)
    uint256 public totalCollateral; // Total collateral deposited by borrowers
    uint256 public assetsCap; // Maximum allowed deposited asset (default 0)
    mapping(address => uint256) private userCollateral; // User's deposited collateral (in wstTokens)
    mapping(address => uint256) private userDebtShares; // User's debt shares

    uint256 private debtPricePerShare = 10**18; // Price per debt share, increases over time
    uint256 public constant SCALE_FACTOR = 10**18; // Scaling factor for 18 decimals
    uint256 public constant SECONDS_PER_YEAR = 31_536_000; // 365 * 24 * 60 * 60
    uint256 public lastUpdateTimestamp; // Last time interest was updated
    uint256 public constant RATE_DENOMINATOR = 10000; // For bps (100% = 10000 bps)

    // LTV, now in bps
    uint256 public constant MAX_LTV = 9500; // 95% = 9500 bps
    uint256 public ltv = 0; // Default to 0 (borrowing disabled), in bps

    // Default borrowing rate params, in bps
    uint256 public minBorrowingRate = 0;
    uint256 public vertexBorrowingRate = 1000;
    uint256 public maxBorrowingRate = 25000;
    uint256 public vertexUtilization = 9000;

    // Interest tracking
    uint256 public stabilityFees;

    // Stability fee params
    uint256 public constant MAX_STABILITY_FEE = 4500;
    uint256 public stabilityFee = 3000;

    // liquidation params
    address private liquidator; // Address authorized to perform liquidations
    uint256 public liquidationBonus = 500; // 5% = 500 bps
    uint256 public constant MAX_LIQUIDATION_BONUS = 1000; // 10% = 1000 bps
    uint256 public constant LIQUIDATION_THRESHOLD = 1e18; // Health factor < 1

    // Base balances for rebasing (unscaled values)
    mapping(address => uint256) private baseBalances; // Unscaled balances
    uint256 private baseTotalSupply; // Unscaled total supply

    // Events
    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event UpdateMinDeposit(uint256 _minDeposit);
    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event UpdateLTV(uint256 newLTV);
    event UpdateBorrowingRateParams(uint256 minRate, uint256 vertexRate, uint256 maxRate, uint256 vertexUtilization);
    event Recover(address indexed receiver, uint256 amount);
    event UpdateStabilityFee(uint256 newFee);
    event CollectStabilityFees(address indexed receiver, uint256 amount);
    event UpdateAssetsCap(uint256 newCap);
    event Liquidation(address indexed user, address indexed liquidator, uint256 debtCovered, uint256 collateralSeized);
    event UpdateLiquidator(address indexed newLiquidator);
    event UpdateLiquidationBonus(uint256 newBonus);

    // Modifier for liquidator-only access
    modifier onlyLiquidator() {
        require(msg.sender == liquidator, "NotLiquidator");
        _;
    }

    constructor(IERC4626 _collateralToken)
        ERC20(
            "AF Lending Pool Token",
            string(abi.encodePacked("afl", _collateralToken.symbol())),
            _collateralToken.decimals()
        )
    {
        collateral = _collateralToken;
        lastUpdateTimestamp = block.timestamp;
        liquidator = msg.sender;
    }

    // Helper function to calculate pending interest for a given number of debt shares
    function _getPendingInterest(uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        uint256 currentDebtValue = (shares * getPricePerShareDebt()) / SCALE_FACTOR;
        uint256 principal = shares; // Initial debtPricePerShare was 1 * SCALE_FACTOR
        return currentDebtValue > principal ? currentDebtValue - principal : 0;
    }

    function getTotalPendingInterest() public view returns (uint256) {
        return _getPendingInterest(totalDebtShares);
    }

    function getUserPendingInterest(address user) public view returns (uint256) {
        return _getPendingInterest(userDebtShares[user]);
    }

    // Calculate price per share (liquidity index) for deposits
    function getPricePerShare() public view returns (uint256) {
        if (baseTotalSupply == 0) return SCALE_FACTOR; // 1:1 initially
        
        uint256 grossInterest = getTotalPendingInterest();
        uint256 totalValue = totalAssets;
        
        if (grossInterest > 0) {
            // Calculate the stability fee portion
            uint256 stabilityFeeRate = _getStabilityFeeRate();
            uint256 fee = (grossInterest * stabilityFeeRate) / RATE_DENOMINATOR;
            uint256 netInterest = grossInterest - fee;
            totalValue += netInterest;
        }
        
        return (totalValue * SCALE_FACTOR) / baseTotalSupply;
    }

    // Calculate price per debt share
    function getPricePerShareDebt() public view returns (uint256) {
        if (totalDebtShares == 0) return SCALE_FACTOR; // 1:1 initially
        uint256 totalDebtValue = (totalDebtShares * debtPricePerShare) / SCALE_FACTOR;
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed == 0 || totalDebtValue == 0) return debtPricePerShare;
        uint256 rate = getBorrowingRate();
        // Scale the rate from bps to a SCALE_FACTOR multiplier
        uint256 scaledRate = (rate * SCALE_FACTOR) / RATE_DENOMINATOR;
        uint256 interest = (totalDebtValue * scaledRate * timeElapsed) / (SCALE_FACTOR * SECONDS_PER_YEAR);
        uint256 interestFactor = (interest * SCALE_FACTOR) / totalDebtValue;
        return debtPricePerShare + (debtPricePerShare * interestFactor) / SCALE_FACTOR;
    }

    // Override balanceOf to return scaled balance
    function balanceOf(address account) public view virtual override returns (uint256) {
        return (baseBalances[account] * getPricePerShare()) / SCALE_FACTOR;
    }

    // Override totalSupply to return scaled total supply
    function totalSupply() public view virtual override returns (uint256) {
        return (baseTotalSupply * getPricePerShare()) / SCALE_FACTOR;
    }

    // Override transfer to adjust for price per share
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 baseAmount = (amount * SCALE_FACTOR) / getPricePerShare();
        require(baseAmount <= baseBalances[msg.sender], "InsufficientBalance");
        baseBalances[msg.sender] -= baseAmount;
        baseBalances[recipient] += baseAmount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    // Override transferFrom to adjust for price per share
    function transferFrom(address sender, address receiver, uint256 amount) public virtual override returns (bool) {
        uint256 baseAmount = (amount * SCALE_FACTOR) / getPricePerShare();
        require(baseAmount <= baseBalances[sender], "InsufficientBalance");

        uint256 currentAllowance = allowance(sender, msg.sender);
        require(currentAllowance >= amount, "InsufficientAllowance");
        _approve(sender, msg.sender, currentAllowance - amount);

        baseBalances[sender] -= baseAmount;
        baseBalances[receiver] += baseAmount;
        emit Transfer(sender, receiver, amount);
        return true;
    }

    // Override _mint to update base balances
    function _mint(address account, uint256 amount) internal virtual override {
        baseTotalSupply += amount;
        baseBalances[account] += amount;
        emit Transfer(address(0), account, (amount * getPricePerShare()) / SCALE_FACTOR);
    }

    // Override _burn to update base balances
    function _burn(address account, uint256 amount) internal virtual override {
        require(baseBalances[account] >= amount, "BurnExceedsBalance");
        baseTotalSupply -= amount;
        baseBalances[account] -= amount;
        emit Transfer(account, address(0), (amount * getPricePerShare()) / SCALE_FACTOR);
    }

    // Recover excess ETH
    function recover(uint256 amount, address receiver) public virtual onlyOwner {
        uint256 excessBalance = address(this).balance > totalAssets ? address(this).balance - totalAssets : 0;
        require(amount <= excessBalance, "AmountExceedsExcess");
        require(address(this).balance >= totalAssets + amount, "InsufficientBalance");

        SafeTransferLib.safeTransferETH(receiver, amount);
        emit Recover(receiver, amount);
    }

    // Deposit/withdraw for ERC20 pool token
    function deposit(address receiver) public payable virtual nonReentrant {
        require(totalAssets + msg.value <= assetsCap, "ExceedsAssetsCap");

        _updateInterest(); // Accrue pending interest before deposit

        // Calculate base tokens to mint based on current price per share
        uint256 baseTokens = (msg.value * SCALE_FACTOR) / getPricePerShare();
        totalAssets += msg.value;
        _mint(receiver, baseTokens);

        emit Deposit(msg.sender, receiver, msg.value, baseTokens);
    }

    function withdraw(uint256 amount, address receiver) public virtual nonReentrant {
        require(amount > 0, "ZeroAmount");
        require(amount <= balanceOf(msg.sender), "InsufficientBalance");
        require(totalAssets > 0, "NoDeposits");

        _updateInterest(); // Accrue pending interest before withdraw

        // Calculate base tokens to burn based on current price per share
        uint256 baseTokens = (amount * SCALE_FACTOR) / getPricePerShare();
        require(baseTokens <= baseBalances[msg.sender], "InsufficientBaseBalance");

        // Check if the contract has enough ETH to cover the withdrawal
        require(address(this).balance >= amount, "InsufficientContractBalance");

        totalAssets -= amount;
        _burn(msg.sender, baseTokens);

        SafeTransferLib.safeTransferETH(receiver, amount);
        emit Withdraw(msg.sender, receiver, amount, baseTokens);
    }

    // BaseLending Logic
    function getVersion() public view virtual returns (string memory) {
        return string(abi.encodePacked(VERSION, ":", LENDING_TYPE));
    }

    function _getCollateralValue(address user) internal view returns (uint256) {
        return _getCollateralValueFromShares(userCollateral[user]);
    }

    function _getCollateralValueFromShares(uint256 shares) internal view returns (uint256) {
        return (shares * collateral.pricePerShare()) / SCALE_FACTOR;
    }

    function getUtilizationRate() public view returns (uint256) {
        if (totalAssets == 0) return 0;
        uint256 totalDebtValue = (totalDebtShares * debtPricePerShare) / SCALE_FACTOR;
        return (totalDebtValue * RATE_DENOMINATOR) / totalAssets;
    }

    function getBorrowingRate() public view returns (uint256) {
        uint256 utilization = getUtilizationRate();
        if (utilization == vertexUtilization) {
            return vertexBorrowingRate;
        } else if (utilization < vertexUtilization) {
            uint256 rateDiff = vertexBorrowingRate - minBorrowingRate;
            return minBorrowingRate + (utilization * rateDiff) / vertexUtilization;
        } else {
            uint256 rateDiff = maxBorrowingRate - vertexBorrowingRate;
            uint256 utilDiff = utilization - vertexUtilization;
            uint256 utilRange = RATE_DENOMINATOR - vertexUtilization;
            return vertexBorrowingRate + (utilDiff * rateDiff) / utilRange;
        }
    }

    function getBorrowingRateParams() public view returns (
        uint256 minRate,
        uint256 vertexRate,
        uint256 maxRate,
        uint256 vertexUtil
    ) {
        return (minBorrowingRate, vertexBorrowingRate, maxBorrowingRate, vertexUtilization);
    }

    function _getStabilityFeeRate() internal view returns (uint256) {
        uint256 utilization = getUtilizationRate();
        if (utilization <= vertexUtilization) {
            return stabilityFee;
        } else {
            uint256 maxFee = stabilityFee * 2; // 2x stabilityFee at 100% utilization
            uint256 feeDiff = maxFee - stabilityFee;
            uint256 utilDiff = utilization - vertexUtilization;
            uint256 utilRange = RATE_DENOMINATOR - vertexUtilization;
            return stabilityFee + (utilDiff * feeDiff) / utilRange;
        }
    }

    function getLendingRate() public view returns (uint256) {
        uint256 borrowingRate = getBorrowingRate();
        uint256 stabilityFeeRateInBps = _getStabilityFeeRate();
        uint256 utilization = getUtilizationRate();
        
        // Calculate lending rate as: borrowingRate * utilization * (1 - stabilityFeeRate)
        uint256 feeFactor = RATE_DENOMINATOR - stabilityFeeRateInBps; // 1 - stabilityFeeRate
        uint256 lendingRate = (borrowingRate * utilization * feeFactor) / (RATE_DENOMINATOR * RATE_DENOMINATOR);
        
        return lendingRate;
    }

    function getUserMaxBorrow(address user) public view returns (uint256) {
        uint256 collateralValue = _getCollateralValue(user);
        uint256 userDebtValue = (userDebtShares[user] * getPricePerShareDebt()) / SCALE_FACTOR;
        // Scale ltv from bps to a SCALE_FACTOR multiplier
        uint256 scaledLtv = (ltv * SCALE_FACTOR) / RATE_DENOMINATOR;
        uint256 maxBorrowable = (collateralValue * scaledLtv) / SCALE_FACTOR;
        return maxBorrowable > userDebtValue ? maxBorrowable - userDebtValue : 0;
    }

    function getUserMaxWithdraw(address user) public view returns (uint256) {
        uint256 userBalance = balanceOf(user);
        uint256 contractBalance = address(this).balance;
        return userBalance < contractBalance ? userBalance : contractBalance;
    }

    function getUserCollateral(address user) public view returns (uint256) {
        return userCollateral[user];
    }

    function getUserDebtShares(address user) public view returns (uint256) {
        return userDebtShares[user];
    }

    function getUserDebtValue(address user) public view returns (uint256) {
        return (userDebtShares[user] * getPricePerShareDebt()) / SCALE_FACTOR;
    }

    function _updateInterest() internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed > 0 && totalDebtShares > 0) {
            uint256 borrowingRate = getBorrowingRate();
            // Scale the rate from bps to a SCALE_FACTOR multiplier
            uint256 scaledRate = (borrowingRate * SCALE_FACTOR) / RATE_DENOMINATOR;
            // Compute interest on the total debt in ETH
            uint256 totalDebtValue = (totalDebtShares * debtPricePerShare) / SCALE_FACTOR;
            uint256 borrowingInterest = (totalDebtValue * scaledRate * timeElapsed) / (SCALE_FACTOR * SECONDS_PER_YEAR);

            // Update debtPricePerShare
            uint256 interestFactor = (borrowingInterest * SCALE_FACTOR) / totalDebtValue;
            debtPricePerShare = debtPricePerShare + (debtPricePerShare * interestFactor) / SCALE_FACTOR;

            // Calculate protocol fee
            uint256 stabilityFeeRate = _getStabilityFeeRate();
            uint256 fee = (borrowingInterest * stabilityFeeRate) / RATE_DENOMINATOR;
            uint256 lenderInterest = borrowingInterest - fee;

            // Update state
            totalAssets += lenderInterest;
            stabilityFees += fee;
            lastUpdateTimestamp = block.timestamp;
        }
    }

    // Collect protocol fees
    function collectStabilityFees(address receiver) public onlyOwner {
        require(stabilityFees > 0, "NoFeesToCollect");

        uint256 contractBalance = address(this).balance;
        uint256 amountToCollect;

        if (stabilityFees > contractBalance) {
            amountToCollect = contractBalance;
            stabilityFees -= amountToCollect;
        } else {
            amountToCollect = stabilityFees;
            stabilityFees = 0;
        }

        SafeTransferLib.safeTransferETH(receiver, amountToCollect);
        emit CollectStabilityFees(receiver, amountToCollect);
    }

    function depositCollateral(uint256 amount) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        userCollateral[msg.sender] += amount;
        totalCollateral += amount;
        emit DepositCollateral(msg.sender, amount);
    }

    function borrow(uint256 amount) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        require(address(this).balance >= amount, "InsufficientBalance");
        uint256 collateralValue = _getCollateralValue(msg.sender);
        uint256 userDebtValue = (userDebtShares[msg.sender] * debtPricePerShare) / SCALE_FACTOR;
        uint256 newDebtValue = userDebtValue + amount;
        // Scale ltv from bps to a SCALE_FACTOR multiplier
        uint256 scaledLtv = (ltv * SCALE_FACTOR) / RATE_DENOMINATOR;
        require(newDebtValue <= (collateralValue * scaledLtv) / SCALE_FACTOR, "InsufficientCollateral");

        // Convert asset amount to debt shares
        uint256 newDebtShares = (amount * SCALE_FACTOR) / debtPricePerShare;
        userDebtShares[msg.sender] += newDebtShares;
        totalDebtShares += newDebtShares;

        SafeTransferLib.safeTransferETH(msg.sender, amount);
        emit Borrow(msg.sender, amount);
    }

    function repay() public payable virtual nonReentrant {
        _updateInterest();
        require(msg.value > 0, "ZeroAmount");

        uint256 userShares = userDebtShares[msg.sender];
        require(userShares > 0, "NoDebt");

        // Calculate the user's total debt in ETH
        uint256 totalDebtValue = (userShares * debtPricePerShare) / SCALE_FACTOR;

        // Determine repayment amount
        uint256 repayment = msg.value > totalDebtValue ? totalDebtValue : msg.value;

        // If repaying the full debt, set shares to 0 to avoid rounding errors
        if (repayment == totalDebtValue) {
            totalDebtShares -= userShares;
            userDebtShares[msg.sender] = 0;
        } else {
            // Convert repayment amount to debt shares
            uint256 sharesRepaid = (repayment * SCALE_FACTOR) / debtPricePerShare;
            userDebtShares[msg.sender] -= sharesRepaid;
            totalDebtShares -= sharesRepaid;
        }

        emit Repay(msg.sender, repayment);

        // Refund any excess ETH sent beyond the total debt
        if (msg.value > totalDebtValue) {
            SafeTransferLib.safeTransferETH(msg.sender, msg.value - totalDebtValue);
        }
    }

    function withdrawCollateral(uint256 amount) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "LessThanMin");
        require(userCollateral[msg.sender] >= amount, "InsufficientCollateral");
        uint256 remainingCollateral = userCollateral[msg.sender] - amount;
        uint256 remainingValue = _getCollateralValueFromShares(remainingCollateral);
        uint256 userDebtValue = (userDebtShares[msg.sender] * debtPricePerShare) / SCALE_FACTOR;
        uint256 scaledLtv = (ltv * SCALE_FACTOR) / RATE_DENOMINATOR;
        require(userDebtValue <= (remainingValue * scaledLtv) / SCALE_FACTOR, "Undercollateralized");
        userCollateral[msg.sender] = remainingCollateral;
        totalCollateral -= amount;
        collateral.safeTransfer(msg.sender, amount);
        emit WithdrawCollateral(msg.sender, amount);
    }

    // Read methods
    function getUserCollateralValue(address user) public view returns (uint256) {
        return _getCollateralValue(user);
    }

    function getUserHealth(address user) public view returns (uint256) {
        uint256 borrowed = getUserDebtValue(user);
        if (borrowed == 0) return type(uint256).max;
        uint256 collateralValue = _getCollateralValue(user);
        uint256 scaledLtv = (ltv * SCALE_FACTOR) / RATE_DENOMINATOR;
        return (collateralValue * scaledLtv) / borrowed;
    }

    function isLiquidatable(address user) public view returns (bool) {
        return getUserHealth(user) < LIQUIDATION_THRESHOLD;
    }

    function getUserMaxWithdrawCollateral(address user) public view returns (uint256) {
        uint256 borrowed = (userDebtShares[user] * getPricePerShareDebt()) / SCALE_FACTOR;
        if (borrowed == 0) return userCollateral[user];
        uint256 collateralValue = _getCollateralValue(user);
        // Scale ltv from bps to a SCALE_FACTOR multiplier
        uint256 scaledLtv = (ltv * SCALE_FACTOR) / RATE_DENOMINATOR;
        if (collateralValue <= (borrowed * SCALE_FACTOR) / scaledLtv) return 0;
        uint256 excessValue = collateralValue - (borrowed * SCALE_FACTOR) / scaledLtv;
        uint256 excessShares = (excessValue * SCALE_FACTOR) / collateral.pricePerShare();
        return excessShares > userCollateral[user] ? userCollateral[user] : excessShares;
    }

    // Liquidator functions
    function liquidate(address user, uint256 debtSharesToCover) public payable virtual onlyLiquidator nonReentrant {
        _updateInterest(); // Accrue interest to ensure debt and collateral values are up-to-date
        require(isLiquidatable(user), "PositionNotLiquidatable");
        require(debtSharesToCover > 0 && debtSharesToCover <= userDebtShares[user], "InvalidDebtSharesAmount");
        
        // Calculate debt value equivalent
        uint256 debtToCover = (debtSharesToCover * getPricePerShareDebt()) / SCALE_FACTOR;
        
        // Calculate collateral to seize
        uint256 collateralPricePerShare = collateral.pricePerShare();
        uint256 collateralValue = (userCollateral[user] * collateralPricePerShare) / SCALE_FACTOR;
        
        // Apply liquidation bonus, capped at available collateral
        uint256 bonusAmount = (debtToCover * liquidationBonus) / RATE_DENOMINATOR;
        uint256 maxBonus = collateralValue > debtToCover ? collateralValue - debtToCover : 0;
        bonusAmount = bonusAmount > maxBonus ? maxBonus : bonusAmount;
        uint256 totalValueToSeize = debtToCover + bonusAmount;
        
        require(totalValueToSeize <= collateralValue, "InsufficientCollateralValue");
        uint256 collateralSharesToSeize = (totalValueToSeize * SCALE_FACTOR) / collateralPricePerShare;
        require(collateralSharesToSeize <= userCollateral[user], "InsufficientCollateralShares");
        
        // Transfer asset from liquidator to protocol
        require(msg.value >= debtToCover, "InsufficientMsgValue");
        if (msg.value > debtToCover) {
            uint256 refund = msg.value - debtToCover;
            SafeTransferLib.safeTransferETH(msg.sender, refund);
        }
        
        // Update user and protocol state
        userDebtShares[user] -= debtSharesToCover;
        totalDebtShares -= debtSharesToCover;
        userCollateral[user] -= collateralSharesToSeize;
        totalCollateral -= collateralSharesToSeize;
        
        // Transfer collateral to liquidator
        collateral.safeTransfer(msg.sender, collateralSharesToSeize);
        
        emit Liquidation(user, msg.sender, debtToCover, collateralSharesToSeize);
    }

    // Admin functions
    function updateLTV(uint256 newLTV) public onlyOwner {
        require(newLTV <= MAX_LTV, "LTVExceedsMax");
        ltv = newLTV;
        emit UpdateLTV(newLTV);
    }

    function updateBorrowingRateParams(
        uint256 newMinRate,
        uint256 newVertexRate,
        uint256 newMaxRate,
        uint256 newVertexUtilization
    ) public onlyOwner {
        require(newMinRate <= newVertexRate && newVertexRate <= newMaxRate, "InvalidRateOrder");
        require(newVertexUtilization > 0 && newVertexUtilization < RATE_DENOMINATOR, "InvalidVertexUtilization");
        minBorrowingRate = newMinRate;
        vertexBorrowingRate = newVertexRate;
        maxBorrowingRate = newMaxRate;
        vertexUtilization = newVertexUtilization;
        emit UpdateBorrowingRateParams(newMinRate, newVertexRate, newMaxRate, newVertexUtilization);
    }

    function updateStabilityFee(uint256 newFee) public onlyOwner {
        require(newFee <= MAX_STABILITY_FEE, "FeeExceedsMax");
        stabilityFee = newFee;
        emit UpdateStabilityFee(newFee);
    }

    function updateAssetsCap(uint256 newCap) public onlyOwner {
        require(newCap >= totalAssets, "NewMaxBelowCurrentAssets");
        assetsCap = newCap;
        emit UpdateAssetsCap(newCap);
    }

    function updateLiquidator(address newLiquidator) public onlyOwner {
        require(newLiquidator != address(0), "InvalidAddress");
        liquidator = newLiquidator;
        emit UpdateLiquidator(newLiquidator);
    }

    function updateLiquidationBonus(uint256 newBonus) public onlyOwner {
        require(newBonus <= MAX_LIQUIDATION_BONUS, "BonusExceedsMax");
        liquidationBonus = newBonus;
        emit UpdateLiquidationBonus(newBonus);
    }

    receive() external payable {}
}

// NativeLending contract accepts network coin as a borrowable asset for lending
contract NativeLending is BaseLending {

    constructor(IERC4626 _collateralToken) BaseLending(_collateralToken) {
        LENDING_TYPE = "native";
    }

}