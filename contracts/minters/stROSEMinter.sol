// SPDX-License-Identifier: GPL-2.0-or-later
// Forked from https://gist.github.com/CedarMist/adacbb32212cf4f606a44b76dda4ee6c
pragma solidity ^0.8.4;

import "../Minter.sol";

enum SubcallReceiptKind {
    Invalid,
    Delegate,
    UndelegateStart,
    UndelegateDone
}

/// 21 byte version-prefixed address (1 byte version, 20 bytes truncated digest).
type StakingAddress is bytes21;

/// 32 byte secret key.
type StakingSecretKey is bytes32;

/**
 * @title SDK Subcall wrappers
 * @notice Interact with Oasis Runtime SDK modules from Sapphire.
 */
library Subcall {
    string private constant CONSENSUS_DELEGATE = "consensus.Delegate";
    string private constant CONSENSUS_UNDELEGATE = "consensus.Undelegate";
    string private constant CONSENSUS_WITHDRAW = "consensus.Withdraw";
    string private constant CONSENSUS_TAKE_RECEIPT = "consensus.TakeReceipt";
    string private constant ACCOUNTS_TRANSFER = "accounts.Transfer";

    /// Address of the SUBCALL precompile
    address internal constant SUBCALL =
        0x0100000000000000000000000000000000000103;

    /// Raised if the underlying subcall precompile does not succeed
    error SubcallError();

    /// There was an error parsing the receipt
    error ParseReceiptError(uint64 receiptId);

    error ConsensusUndelegateError(uint64 status, string data);

    error ConsensusDelegateError(uint64 status, string data);

    error ConsensusTakeReceiptError(uint64 status, string data);

    error ConsensusWithdrawError(uint64 status, string data);

    error AccountsTransferError(uint64 status, string data);

    /// Name of token cannot be CBOR encoded with current functions
    error TokenNameTooLong();

    /// While parsing CBOR map, unexpected key
    error InvalidKey();

    /// While parsing CBOR map, length is invalid, or other parse error
    error InvalidMap();

    /// While parsing CBOR structure, data length was unexpected
    error InvalidLength();

    /// Invalid receipt ID
    error InvalidReceiptId();

    /// CBOR parsed valid is out of expected range
    error ValueOutOfRange();

    /// CBOR parser expected a key, but it was not found in the map!
    error MissingKey();

    /**
     * @notice Submit a native message to the Oasis runtime layer. Messages
     * which re-enter the EVM module are forbidden: `evm.*`.
     * @param method Native message type.
     * @param body CBOR encoded body.
     * @return status Result of call.
     * @return data CBOR encoded result.
     */
    function subcall(string memory method, bytes memory body)
        internal
        returns (uint64 status, bytes memory data)
    {
        (bool success, bytes memory tmp) = SUBCALL.call(
            abi.encode(method, body)
        );

        if (!success) {
            revert SubcallError();
        }

        (status, data) = abi.decode(tmp, (uint64, bytes));
    }

    /**
     * @notice Generic method to call `{to:address, amount:uint128}`.
     * @param method Runtime SDK method name ('module.Action').
     * @param to Destination address.
     * @param value Amount specified.
     * @return status Non-zero on error.
     * @return data Module name on error.
     */
    function _subcallWithToAndAmount(
        string memory method,
        StakingAddress to,
        uint128 value,
        bytes memory token
    ) internal returns (uint64 status, bytes memory data) {
        // Ensures prefix is in range of 0x40..0x57 (inclusive)
        if (token.length > 19) revert TokenNameTooLong();

        (status, data) = subcall(
            method,
            abi.encodePacked(
                hex"a262",
                "to",
                hex"55",
                to,
                hex"66",
                "amount",
                hex"8250",
                value,
                uint8(0x40 + token.length),
                token
            )
        );
    }

    /**
     * @notice Returns a CBOR encoded structure, containing the following
     * possible keys. All keys are optional:
     *
     *  - shares: `u128`
     *  - epoch: `EpochTime`
     *  - receipt: `u64`
     *  - amount: `u128`
     *  - error: `{module: string, code: u32}`
     *
     * #### Keys returned by specific subcalls
     *
     * - `Delegate` will have the `error` or `shares` keys.
     * - `UndelegateStart` will have the `epoch` and `receipt` keys.
     * - `UndelegateDone` will have the `amount` key.
     *
     * @param kind `1` (`Delegate`), `2` (`UndelegateStart`) or `3` (`UndelegateDone`)
     * @param receiptId ID of receipt
     */
    function consensusTakeReceipt(SubcallReceiptKind kind, uint64 receiptId)
        internal
        returns (bytes memory)
    {
        if (receiptId == 0) revert InvalidReceiptId();

        if (uint256(kind) == 0 || uint256(kind) > 23) revert ValueOutOfRange();

        (bool success, bytes memory data) = SUBCALL.call(
            abi.encode(
                CONSENSUS_TAKE_RECEIPT,
                abi.encodePacked(
                    hex"a2", // Map, 2 pairs
                    hex"62",
                    "id", // Byte string, 2 bytes
                    hex"1b",
                    receiptId, // Unsigned 64bit integer
                    hex"64",
                    "kind", // Byte string, 4 bytes
                    uint8(kind) // uint8 <= 23.
                )
            )
        );

        if (!success) revert SubcallError();

        (uint64 status, bytes memory result) = abi.decode(
            data,
            (uint64, bytes)
        );

        if (status != 0) {
            revert ConsensusTakeReceiptError(status, string(result));
        }

        return result;
    }

    function _parseCBORUint(bytes memory result, uint256 offset)
        public
        pure
        returns (uint256 newOffset, uint256 value)
    {
        if (result[offset] & 0x40 != 0x40) revert InvalidLength();

        uint256 len = uint8(result[offset++]) ^ 0x40;

        if (len >= 0x20) revert InvalidLength();

        assembly {
            value := mload(add(add(0x20, result), offset))
        }

        value = value >> (256 - (len * 8));

        newOffset = offset + len;
    }

    function _parseCBORUint64(bytes memory result, uint256 offset)
        public
        pure
        returns (uint256 newOffset, uint64 value)
    {
        uint256 tmp;

        (newOffset, tmp) = _parseCBORUint(result, offset);

        if (tmp > type(uint64).max) revert ValueOutOfRange();

        value = uint64(tmp);
    }

    function _parseCBORUint128(bytes memory result, uint256 offset)
        public
        pure
        returns (uint256 newOffset, uint128 value)
    {
        uint256 tmp;

        (newOffset, tmp) = _parseCBORUint(result, offset);

        if (tmp > type(uint128).max) revert ValueOutOfRange();

        value = uint128(tmp);
    }

    function _parseCBORKey(bytes memory result, uint256 offset)
        internal
        pure
        returns (uint256 newOffset, bytes32 keyDigest)
    {
        if (result[offset] & 0x60 != 0x60) revert InvalidKey();

        uint8 len = uint8(result[offset++]) ^ 0x60;

        assembly {
            keyDigest := keccak256(add(add(0x20, result), offset), len)
        }

        newOffset = offset + len;
    }

    function _decodeReceiptUndelegateStart(bytes memory result)
        internal
        pure
        returns (uint64 epoch, uint64 endReceipt)
    {
        uint256 offset = 1;

        bool hasEpoch = false;

        bool hasReceipt = false;

        if (result[0] != 0xA2) revert InvalidMap();

        while (offset < result.length) {
            bytes32 keyDigest;

            (offset, keyDigest) = _parseCBORKey(result, offset);

            if (keyDigest == keccak256("epoch")) {
                (offset, epoch) = _parseCBORUint64(result, offset);

                hasEpoch = true;
            } else if (keyDigest == keccak256("receipt")) {
                (offset, endReceipt) = _parseCBORUint64(result, offset);

                hasReceipt = true;
            } else {
                // TODO: skip unknown keys & values? For forward compatibility
                revert InvalidKey();
            }
        }

        if (!hasEpoch || !hasReceipt) revert MissingKey();
    }

    function _decodeReceiptUndelegateDone(bytes memory result)
        internal
        pure
        returns (uint128 amount)
    {
        uint256 offset = 1;

        bool hasAmount = false;

        if (result[0] != 0xA1) revert InvalidMap();

        while (offset < result.length) {
            bytes32 keyDigest;

            (offset, keyDigest) = _parseCBORKey(result, offset);

            if (keyDigest == keccak256("amount")) {
                (offset, amount) = _parseCBORUint128(result, offset);

                hasAmount = true;
            } else {
                // TODO: skip unknown keys & values? For forward compatibility
                revert InvalidKey();
            }
        }

        if (!hasAmount) revert MissingKey();
    }

    /**
     * @notice Decodes a 'Delegate' receipt.
     * @param receiptId Previously unretrieved receipt.
     * @param result CBOR encoded {shares: u128}.
     */
    function _decodeReceiptDelegate(uint64 receiptId, bytes memory result)
        internal
        pure
        returns (uint128 shares)
    {
        if (result[0] != 0xA1) revert InvalidMap();

        if (result[0] == 0xA1 && result[1] == 0x66 && result[2] == "s") {
            // Delegation succeeded, decode number of shares.
            uint8 sharesLen = uint8(result[8]) & 0x1f; // Assume shares field is never greater than 16 bytes.

            if (9 + sharesLen != result.length) revert InvalidLength();

            for (uint256 offset = 0; offset < sharesLen; offset++) {
                uint8 v = uint8(result[9 + offset]);

                shares += uint128(v) << (8 * uint128(sharesLen - offset - 1));
            }
        } else {
            revert ParseReceiptError(receiptId);
        }
    }

    function consensusTakeReceiptDelegate(uint64 receiptId)
        internal
        returns (uint128 shares)
    {
        bytes memory result = consensusTakeReceipt(
            SubcallReceiptKind.Delegate,
            receiptId
        );

        shares = _decodeReceiptDelegate(receiptId, result);
    }

    function consensusTakeReceiptUndelegateStart(uint64 receiptId)
        internal
        returns (uint64 epoch, uint64 endReceipt)
    {
        bytes memory result = consensusTakeReceipt(
            SubcallReceiptKind.UndelegateStart,
            receiptId
        );

        (epoch, endReceipt) = _decodeReceiptUndelegateStart(result);
    }

    function consensusTakeReceiptUndelegateDone(uint64 receiptId)
        internal
        returns (uint128 amount)
    {
        bytes memory result = consensusTakeReceipt(
            SubcallReceiptKind.UndelegateStart,
            receiptId
        );

        (amount) = _decodeReceiptUndelegateDone(result);
    }

    /**
     * @notice Start the undelegation process of the given number of shares from
     * consensus staking account to runtime account.
     * @param from Consensus address which shares were delegated to.
     * @param shares Number of shares to withdraw back to us.
     */
    function consensusUndelegate(StakingAddress from, uint128 shares) internal {
        (uint64 status, bytes memory data) = subcall(
            CONSENSUS_UNDELEGATE,
            abi.encodePacked( // CBOR encoded, {'from': x, 'shares': y}
                hex"a2", // map, 2 pairs
                // pair 1
                hex"64", // UTF-8 string, 4 bytes
                "from",
                hex"55", // 21 bytes
                from,
                // pair 2
                hex"66", // UTF-8 string, 6 bytes
                "shares",
                hex"50", // 128bit unsigned int (16 bytes)
                shares
            )
        );

        if (status != 0) {
            revert ConsensusUndelegateError(status, string(data));
        }
    }

    function consensusUndelegate(
        StakingAddress from,
        uint128 shares,
        uint64 receiptId
    ) internal {
        // XXX: due to weirdness in oasis-cbor, `0x1b || 8 bytes` requires `value >= 2**32`
        if (receiptId < 4294967296) revert InvalidReceiptId();

        (uint64 status, bytes memory data) = subcall(
            CONSENSUS_UNDELEGATE,
            abi.encodePacked( // CBOR encoded, {'from': x, 'shares': y, 'receipt': z}
                hex"a3", // map, 3 pairs
                // pair 1
                hex"64", // UTF-8 string, 4 bytes
                "from",
                hex"55", // 21 bytes
                from,
                // pair 2
                hex"66", // UTF-8 string, 6 bytes
                "shares",
                hex"50", // 16 bytes
                shares,
                // pair 3
                hex"67", // UTF-8 string, 7 bytes
                "receipt",
                hex"1b", // 64bit unsigned int
                receiptId
            )
        );

        if (status != 0) {
            revert ConsensusUndelegateError(status, string(data));
        }
    }

    /**
     * @notice Delegate native token to consensus level.
     * @param to Consensus address shares are delegated to.
     * @param amount Native token amount (in wei).
     */
    function consensusDelegate(StakingAddress to, uint128 amount)
        internal
        returns (bytes memory data)
    {
        uint64 status;

        (status, data) = _subcallWithToAndAmount(
            CONSENSUS_DELEGATE,
            to,
            amount,
            ""
        );

        if (status != 0) {
            revert ConsensusDelegateError(status, string(data));
        }
    }

    /**
     * @notice Delegate native token to consensus level. Requests that the
     * number of shares allocated can be retrieved with a receipt. The receipt
     * will be of `ReceiptKind.DelegateDone` and can be decoded using
     * `decodeReceiptDelegateDone`.
     * @param to Consensus address shares are delegated to.
     * @param amount Native token amount (in wei).
     * @param receiptId contract-specific receipt to retrieve result.
     */
    function consensusDelegate(
        StakingAddress to,
        uint128 amount,
        uint64 receiptId
    ) internal returns (bytes memory data) {
        // XXX: due to weirdness in oasis-cbor, `0x1b || 8 bytes` requires `value >= 2**32`
        if (receiptId < 4294967296) revert InvalidReceiptId();

        uint64 status;

        (status, data) = subcall(
            CONSENSUS_DELEGATE,
            abi.encodePacked( // CBOR encoded, {to: w, amount: [x, y], receipt: z}
                hex"a3", // map, 3 pairs
                // pair 1
                hex"62", // UTF-8 string, 2 byte
                "to",
                hex"55", // byte string, 21 bytes
                to,
                // pair 2
                hex"66", // UTF-8 string, 6 bytes
                "amount",
                hex"82", // Array, 2 elements
                hex"50", // byte string, 16 bytes
                amount,
                // TODO: handle non-native token!
                hex"40", // byte string, 0 to 23 bytes
                // pair 3
                hex"67",
                "receipt", // UTF-8 string, 7 bytes
                hex"1b",
                receiptId // uint64, 8 bytes
            )
        );

        if (status != 0) {
            revert ConsensusDelegateError(status, string(data));
        }
    }

    /**
     * @notice Transfer from an account in this runtime to a consensus staking
     * account.
     * @param to Consensus address which gets the tokens.
     * @param value Token amount (in wei).
     */
    function consensusWithdraw(StakingAddress to, uint128 value) internal {
        (uint64 status, bytes memory data) = _subcallWithToAndAmount(
            CONSENSUS_WITHDRAW,
            to,
            value,
            ""
        );

        if (status != 0) {
            revert ConsensusWithdrawError(status, string(data));
        }
    }

    /**
     * @notice Perform a transfer to another account. This is equivalent of
     * `payable(to).transfer(value);`.
     * @param to Destination account.
     * @param value native token amount (in wei).
     */
    function accountsTransfer(address to, uint128 value) internal {
        (uint64 status, bytes memory data) = _subcallWithToAndAmount(
            ACCOUNTS_TRANSFER,
            StakingAddress.wrap(bytes21(abi.encodePacked(uint8(0x00), to))),
            value,
            ""
        );

        if (status != 0) {
            revert AccountsTransferError(status, string(data));
        }
    }
}

contract stROSEMinter is NativeMinter {

    using SafeMath for uint256;
    using SafeTransferLib for IERC20;

    uint256 public redeemFee = 0; // possible fee to cover bridging costs
    uint256 public constant MAX_REDEEM_FEE = 200; // max redeem fee 200bp (2%)

    uint64 private lastReceiptId; // Incremented counter to determine receipt IDs
    
    mapping(uint64 => PendingDelegation) private pendingDelegations; // (receiptId => PendingDelegation)
    mapping(StakingAddress => Delegation) private delegations; // (to) => shares
    mapping(uint64 => PendingUndelegation) private pendingUndelegations; // (receiptId => PendingUndelegation)

    uint64[] private allPendingDelegationReceipts;
    StakingAddress[] private allDelegationAddresses;
    uint64[] private allPendingUndelegationReceipts;

    constructor(address _stakingToken) NativeMinter(_stakingToken) {
        // Due to an oddity in the oasis-cbor package, we start at 2**32
        // Otherwise uint64 parsing will fail and the message is rejected
        lastReceiptId = 4294967296;
    }

    struct PendingDelegation {
        StakingAddress to;
        uint128 amount;
    }

    struct Delegation {
        uint128 shares;
    }

    struct PendingUndelegation {
        StakingAddress from;
        uint128 shares;
        uint64 endReceiptId;
        uint64 epoch;
    }

    event UpdateRedeemFee(uint256 _redeemFee);
    event Redeem(address indexed caller, address indexed receiver, uint256 amount);

    event OnDelegateStart(StakingAddress to, uint256 amount, uint64 receiptId);
    event OnDelegateDone(uint64 indexed receiptId, uint128 shares);
    event OnUndelegateStart(uint64 indexed receiptId, uint64 epoch, uint128 shares);
    event OnUndelegateDone(StakingAddress from, uint128 shares);

    function previewRedeem(uint256 amount) public view virtual returns (uint256) {
        uint256 feeAmount = amount.mul(redeemFee).div(FEE_DENOMINATOR);
        uint256 netAmount = amount.sub(feeAmount);
        return netAmount;
    }

    function updateRedeemFee(uint256 newFee) public onlyOwner {
        require(newFee <= MAX_DEPOSIT_FEE, ">MaxFee");
        redeemFee = newFee;
        emit UpdateRedeemFee(newFee);
    }

     /**
     * Begin or increase delegation by sending an amount of ROSE to the contract.
     *
     * Delegation will fail if the minimum per-validator amount has not been
     * reached, at the time of writing this is 100 ROSE.
     *
     * See https://docs.oasis.io/node/genesis-doc#delegations.
     *
     * Only one delegation can occur per transaction.
     *
     * @param to Staking address of validator on the consensus layer
     */
    function delegate(StakingAddress to, uint128 amount) public onlyOwner returns (uint64) {
        require(amount < type(uint128).max, ">MaxUint128");
        require(amount > 0, "ZeroDelegate");
        uint64 receiptId = lastReceiptId++;
        Subcall.consensusDelegate(to, amount, receiptId);
        pendingDelegations[receiptId] = PendingDelegation(
            to,
            amount
        );
        allPendingDelegationReceipts.push(receiptId);
        emit OnDelegateStart(to, amount, receiptId);
        return receiptId;
    }

    /**
     * Retrieve the number of shares received in return for delegation.
     *
     * The receipt will only be available after the delegate transaction has
     * been included in a block. It is necessary to wait for the message to
     * reach the consensus layer and be processed to determine the number of
     * shares.
     *
     * @param receiptId Receipt ID previously emitted/returned by `delegate`.
     */
    function delegateDone(uint64 receiptId) public onlyOwner returns (uint128 shares) {
        PendingDelegation memory pending = pendingDelegations[receiptId];
        shares = Subcall.consensusTakeReceiptDelegate(receiptId);
        Delegation storage d = delegations[pending.to];
        d.shares += shares;
        allDelegationAddresses.push(pending.to);
        emit OnDelegateDone(receiptId, shares);
        // Remove pending delegation.
        delete pendingDelegations[receiptId];
        removeItemFromArray(allPendingDelegationReceipts, receiptId);
    }

    /**
     * Begin undelegation of a number of shares
     *
     * @param from Validator which the shares were staked with
     * @param shares Number of shares to debond
     */
    function undelegate(StakingAddress from, uint128 shares)
        public
        onlyOwner
        returns (uint64)
    {
        require(shares > 0, "ZeroUndelegate");
        Delegation storage d = delegations[from];
        require(d.shares >= shares, "NotEnoughShares");

        uint64 receiptId = lastReceiptId++;

        Subcall.consensusUndelegate(from, shares, receiptId);

        d.shares -= shares;

        pendingUndelegations[receiptId] = PendingUndelegation({
            from: from,
            shares: shares,
            endReceiptId: 0,
            epoch: 0
        });

        allPendingUndelegationReceipts.push(receiptId);

        return receiptId;
    }

    /**
     * Process the undelegation step, which returns the end receipt ID and
     * the epoch which debonding will finish.
     *
     * If multiple undelegations to the same validator are processed within
     * the same epoch they will have the same `endReceiptId` as they will finish
     * unbonding on the same epoch.
     *
     * @param receiptId Receipt retuned/emitted from `undelegate`
     */
    function undelegateStart(uint64 receiptId) public onlyOwner {
        PendingUndelegation storage pending = pendingUndelegations[receiptId];

        (uint64 epoch, uint64 endReceipt) = Subcall.consensusTakeReceiptUndelegateStart(receiptId);

        pending.endReceiptId = endReceipt;
        pending.epoch = epoch;

        emit OnUndelegateStart(receiptId, epoch, pending.shares);
    }

    /**
     * Finish the undelegation process, transferring the staked ROSE back.
     *
     * @param receiptId returned/emitted from `undelegateStart`
     */
    function undelegateDone(uint64 receiptId) public onlyOwner {
        PendingUndelegation memory pending = pendingUndelegations[receiptId];
        require(pending.endReceiptId>0, "MustUndelegateStartFirst");
        uint128 amount = Subcall.consensusTakeReceiptUndelegateDone(
            pending.endReceiptId
        );
        require(amount>0, "ZeroUndelegate");
        delete pendingUndelegations[receiptId];
        removeItemFromArray(allPendingUndelegationReceipts, receiptId);
    }

    function redeem(uint256 amount, address receiver) public nonReentrant {
        require(amount > 0, "ZeroRedeem");
        uint256 redeemAmount = previewRedeem(amount);
        require(redeemAmount > 0, "ZeroRedeemAmount");
        stakingToken.safeTransferFrom(address(msg.sender), address(this), amount);
        stakingToken.burn(amount);
        SafeTransferLib.safeTransferETH(receiver, redeemAmount);
        emit Redeem(address(msg.sender), receiver, amount);
    }

    function withdraw(address receiver) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdraw function disabled for ", receiver)));
    }

    function getAllPendingDelegations() public view returns (uint64[] memory) {
        return allPendingDelegationReceipts;
    }

    function getAllDelegations() public view returns (StakingAddress[] memory) {
        return allDelegationAddresses;
    }

    function getAllPendingUndelegations() public view returns (uint64[] memory) {
        return allPendingUndelegationReceipts;
    }

    /**
     * Get information about a single delegation by staking address.
     *
     * @param staker The staking address of the validator.
     */
    function getDelegationInfo(StakingAddress staker) public view returns (uint128 shares) {
        Delegation memory delegation = delegations[staker];
        shares = delegation.shares;
    }

    /**
     * Get information about a single pending delegation by receipt ID.
     *
     * @param receiptId The ID of the pending delegation receipt.
     */
    function getPendingDelegationInfo(uint64 receiptId) public view returns (StakingAddress to, uint128 amount) {
        PendingDelegation memory pendingDelegation = pendingDelegations[receiptId];
        to = pendingDelegation.to;
        amount = pendingDelegation.amount;
    }

    /**
     * Get information about a single pending undelegation by receipt ID.
     *
     * @param receiptId The ID of the pending undelegation receipt.
     */
    function getPendingUndelegationInfo(uint64 receiptId) public view returns (StakingAddress from, uint128 shares, uint64 endReceiptId, uint64 epoch) {
        PendingUndelegation memory pendingUndelegation = pendingUndelegations[receiptId];
        from = pendingUndelegation.from;
        shares = pendingUndelegation.shares;
        endReceiptId = pendingUndelegation.endReceiptId;
        epoch = pendingUndelegation.epoch;
    }

    function removeItemFromArray(uint64[] storage array, uint64 item) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == item) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }

}