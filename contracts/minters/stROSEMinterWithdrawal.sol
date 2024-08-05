// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../Minter.sol";

/// 21 byte version-prefixed address (1 byte version, 20 bytes truncated digest).
type StakingAddress is bytes21;

/// 32 byte secret key.
type StakingSecretKey is bytes32;

enum SubcallReceiptKind {
    Invalid,
    Delegate,
    UndelegateStart,
    UndelegateDone
}

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
    error InvalidLength(uint256);

    /// Invalid receipt ID
    error InvalidReceiptId();

    /// CBOR parsed valid is out of expected range
    error ValueOutOfRange();

    /// CBOR parser expected a key, but it was not found in the map!
    error MissingKey();

    /// Value cannot be parsed as a uint
    error InvalidUintPrefix(uint8);

    /// Unsigned integer of unknown size
    error InvalidUintSize(uint8);

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

        // 0xf6 = null, returns null in case receiptId not found
        if (result[0] == 0xf6) {
            revert InvalidReceiptId();
        }

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
        uint8 prefix = uint8(result[offset]);
        uint256 len;

        if (prefix <= 0x17) {
            return (offset + 1, prefix);
        }
        // Byte array(uint256), parsed as a big-endian integer.
        else if (prefix == 0x58) {
            len = uint8(result[++offset]);
            offset++;
        }
        // Byte array, parsed as a big-endian integer.
        else if (prefix & 0x40 == 0x40) {
            len = uint8(result[offset++]) ^ 0x40;
        }
        // Unsigned integer, CBOR encoded.
        else if (prefix & 0x10 == 0x10) {
            if (prefix == 0x18) {
                len = 1;
            } else if (prefix == 0x19) {
                len = 2;
            } else if (prefix == 0x1a) {
                len = 4;
            } else if (prefix == 0x1b) {
                len = 8;
            } else {
                revert InvalidUintSize(prefix);
            }
            offset += 1;
        }
        // Unknown...
        else {
            revert InvalidUintPrefix(prefix);
        }

        if (len > 0x20) revert InvalidLength(len);

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

            if (9 + sharesLen != result.length) revert InvalidLength(sharesLen);

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
            SubcallReceiptKind.UndelegateDone,
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

contract stROSEMinterWithdrawal is NativeMinterWithdrawal {

    using SafeTransferLib for IERC20;

    uint64 public lastReceiptId; // Incremented counter to determine receipt IDs
    
    mapping(StakingAddress => Delegation) private delegations; // (validator => Delegation)
    mapping(uint64 => DelegationReceipt) private delegationReceipts; // (receiptId => DelegationReceipt)
    mapping(uint64 => UndelegationReceipt) private undelegationReceipts; // (receiptId => UndelegationReceipt)
    mapping(uint64 => uint64[]) private endReceiptIdToReceiptIds; // (endReceiptId => array of receiptIds)

    uint64[] private allEndReceiptIds;
    StakingAddress[] private allDelegations;

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstROSE", "unstROSE") {
        // Due to an oddity in the oasis-cbor package, we start at 2**32
        // Otherwise uint64 parsing will fail and the message is rejected
        lastReceiptId = 4294967296;
    }

    struct Delegation {
        uint128 amount;
        uint128 shares;
    }

    struct DelegationReceipt {
        bool exists;
        StakingAddress to;
        uint256 blockNumber;
        bool receiptTaken;
        uint256 receiptTakenBlockNumber;
        uint128 shares;
        uint128 amount;
    }

    struct UndelegationReceipt {
        bool exists;
        StakingAddress from;
        uint256 blockNumber;
        bool receiptStartTaken;
        uint256 receiptStartTakenBlockNumber;
        bool receiptDoneTaken;
        uint256 receiptDoneTakenBlockNumber;
        uint64 epoch;
        uint64 endReceiptId;
        uint128 shares;
        uint128 amount;
    }

    event Delegate(StakingAddress to, uint128 amount, uint64 indexed receiptId);
    event TakeReceiptDelegate(uint64 indexed receiptId);
    event Undelegate(StakingAddress from, uint128 shares, uint64 indexed receiptId);
    event TakeReceiptUndelegateStart(uint64 indexed receiptId, uint64 indexed epoch, uint64 indexed endReceiptId);
    event TakeReceiptUndelegateDone(uint64 indexed endReceiptId, uint128 amount);
    event UndelegateDone(StakingAddress from, uint128 shares, uint128 amount, uint64 indexed receiptId);

    // Function to compare two StakingAddress values
    function _areEqual(StakingAddress a, StakingAddress b) internal pure returns (bool) {
        return StakingAddress.unwrap(a) == StakingAddress.unwrap(b);
    }

    // Function to add a validator while avoiding duplicates
    function _addDelegation(StakingAddress validator) internal {
        // Check if the address already exists in the array
        bool exists = false;
        for (uint256 i = 0; i < allDelegations.length; i++) {
            if (_areEqual(allDelegations[i], validator)) {
                exists = true;
                break;
            }
        }

        // If the address does not exist, add it to the array
        if (!exists) {
            allDelegations.push(validator);
        }
    }

    // Function to remove a validator
    function _removeDelegation(StakingAddress validator) internal {
        for (uint256 i = 0; i < allDelegations.length; i++) {
            if (_areEqual(allDelegations[i], validator)) {
                // Move the last element into the place to delete
                allDelegations[i] = allDelegations[allDelegations.length - 1];
                // Remove the last element
                allDelegations.pop();
                break;
            }
        }
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
        delegationReceipts[receiptId] = DelegationReceipt({
            exists: true,
            to: to,
            blockNumber: block.number,
            receiptTaken: false,
            receiptTakenBlockNumber: 0,
            shares: 0,
            amount: amount
        });
        emit Delegate(to, amount, receiptId);
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
    function takeReceiptDelegate(uint64 receiptId) public onlyOwner returns (uint128 shares) {
        DelegationReceipt storage receipt = delegationReceipts[receiptId];
        require(block.number > receipt.blockNumber, "ReceiptNotReady");
        require(receipt.exists, "ReceiptNotExists");
        require(receipt.receiptTaken == false, "AlreadyTaken");
        shares = Subcall.consensusTakeReceiptDelegate(receiptId);
        Delegation storage delegation = delegations[receipt.to];
        if (delegation.shares != 0)
        {
            // convert from assets to shares with support for rounding direction.
            // https://github.com/OpenZeppelin/openzeppelin-contracts/blob/bd325d56b4c62c9c5c1aff048c37c6bb18ac0290/contracts/token/ERC20/extensions/ERC4626.sol#L199
            shares = uint128(Math.mulDiv(receipt.amount, delegation.shares + (10**18), delegation.amount + 1, Math.Rounding.Ceil));
        }

        // Update receipt with the necessary info
        receipt.shares = shares;
        receipt.receiptTaken = true;
        receipt.receiptTakenBlockNumber = block.number;

        delegation.amount += receipt.amount;
        delegation.shares += shares;
        
        allDelegations.push(receipt.to);
        
        emit TakeReceiptDelegate(receiptId);
    }

    /**
     * Begin undelegation of a number of shares
     *
     * @param from Validator which the shares were staked with
     * @param shares Number of shares to debond
     */
    function undelegate(StakingAddress from, uint128 shares) public onlyOwner
    {
        Delegation storage d = delegations[from];
        require(shares > 0, "ZeroUndelegate");
        require(d.shares >= shares, "NotEnoughShares");

        uint64 receiptId = lastReceiptId++;

        Subcall.consensusUndelegate(from, shares, receiptId);

        undelegationReceipts[receiptId] = UndelegationReceipt({
            exists: true,
            from: from,
            blockNumber: block.number,
            receiptStartTaken: false,
            receiptStartTakenBlockNumber: 0,
            receiptDoneTaken: false,
            receiptDoneTakenBlockNumber: 0,
            epoch: 0,
            endReceiptId: 0,
            shares: shares,
            amount: 0
        });

        emit Undelegate(from, shares, receiptId);
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
    function takeReceiptUndelegateStart(uint64 receiptId) public onlyOwner {
        UndelegationReceipt storage receipt = undelegationReceipts[receiptId];
        require(block.number > receipt.blockNumber, "ReceiptNotReady");
        require(receipt.exists == true, "ReceiptNotExists");
        require(receipt.receiptStartTaken == false, "AlreadyTaken");

        (uint64 epoch, uint64 endReceiptId) = Subcall.consensusTakeReceiptUndelegateStart(receiptId);

        receipt.receiptStartTaken = true;
        receipt.receiptStartTakenBlockNumber = block.number;
        receipt.epoch = epoch;
        receipt.endReceiptId = endReceiptId;

        // map receiptId to endReceiptId
        endReceiptIdToReceiptIds[endReceiptId].push(receiptId);
        allEndReceiptIds.push(endReceiptId);

        emit TakeReceiptUndelegateStart(receiptId, epoch, endReceiptId);
    }

    /**
     * Finish the undelegation process, transferring the staked ROSE back.
     *
     * @param endReceiptId returned by `undelegateStart`
     */
    function takeReceiptUndelegateDone(uint64 endReceiptId) public onlyOwner {
        // get all undelegate receiptIds containing endReceiptId
        uint64[] memory receiptIds = endReceiptIdToReceiptIds[endReceiptId];

        require(receiptIds.length > 0, "NoReceiptsForEndReceiptId");
        
        for (uint64 i = 0; i < receiptIds.length; i++) {
            uint64 receiptId = receiptIds[i];
            UndelegationReceipt memory receipt = undelegationReceipts[receiptId];
            require(receipt.exists == true, "ReceiptNotExists");
            require(receipt.receiptStartTaken == true, "NotStarted");
            require(receipt.receiptDoneTaken == false, "AlreadyTaken");
        }

        uint128 totalAmount = Subcall.consensusTakeReceiptUndelegateDone(
            endReceiptId
        );
        require(totalAmount>0, "ZeroUndelegate");
        emit TakeReceiptUndelegateDone(endReceiptId, totalAmount);

        for (uint64 i = 0; i < receiptIds.length; i++) {
            UndelegationReceipt storage receipt = undelegationReceipts[i];
            Delegation storage delegation = delegations[receipt.from];

            receipt.receiptDoneTaken = true;
            receipt.receiptDoneTakenBlockNumber = block.number;

            uint128 amount;

            // if no shares left, deduct entire amount
            if (receipt.shares == delegation.shares) {
                amount = delegation.amount;
            } else {
                amount = uint128(Math.mulDiv(receipt.shares, delegation.amount + 1, delegation.shares + (10**18), Math.Rounding.Floor));
            }

            receipt.amount = amount;

            delegation.shares -= receipt.shares;
            delegation.amount -= amount;
            emit UndelegateDone(receipt.from, receipt.shares, amount, i);
        }

    }

    function emergencyTakeReceiptDelegate(uint64 receiptId) public onlyOwner returns (uint128 shares) {
        shares = Subcall.consensusTakeReceiptDelegate(receiptId);
    }

    function emergencyUndelegate(StakingAddress from, uint128 shares, uint64 receiptId) public onlyOwner
    {
        Subcall.consensusUndelegate(from, shares, receiptId);
    }

    function emergencyTakeReceiptUndelegateStart(uint64 receiptId) public onlyOwner returns (uint64 epoch, uint64 endReceiptId) {
        (epoch, endReceiptId) = Subcall.consensusTakeReceiptUndelegateStart(receiptId);
    }

    function emergencyTakeReceiptUndelegateDone(uint64 endReceiptId) public onlyOwner returns (uint128 amount) {
        amount = Subcall.consensusTakeReceiptUndelegateDone(endReceiptId);
    }

    function withdraw(address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

    function getAllDelegations() public view returns (StakingAddress[] memory) {
        return allDelegations;
    }

    /**
     * Get information about a single delegation by staking address.
     *
     * @param validator The staking address of the validator.
     */
    function getDelegation(StakingAddress validator) public view returns (Delegation memory delegation) {
        return delegations[validator];
    }

    /**
     * Get information about a single delegation by receipt ID.
     *
     * @param receiptId The ID of the delegation receipt.
     */
    function getDelegationReceipt(uint64 receiptId) public view returns (DelegationReceipt memory receipt) {
        return delegationReceipts[receiptId];
    }

    /**
     * Get information about a single undelegation by receipt ID.
     *
     * @param receiptId The ID of the undelegation receipt.
     */
    function getUndelegationReceipt(uint64 receiptId) public view returns (UndelegationReceipt memory receipt) {
        return undelegationReceipts[receiptId];
    }

    function getAllEndReceiptIds() public view returns (uint64[] memory) {
        return allEndReceiptIds;
    }

    function getReceiptIdsFromEndReceiptId(uint64 endReceiptId) public view returns (uint64[] memory) {
        return endReceiptIdToReceiptIds[endReceiptId];
    }

}