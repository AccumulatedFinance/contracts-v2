// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV203.sol";

/// @author The Evmos Core Team
/// @title Staking Precompile Contract
/// @dev The interface through which solidity contracts will interact with Staking
interface IStaking {

    /// @dev Allocation represents a single allocation for an IBC fungible token transfer.
    struct ICS20Allocation {
        string   sourcePort;
        string   sourceChannel;
        Coin[]   spendLimit;
        string[] allowList;
        string[] allowedPacketData;
    }

    /// @dev Dec represents a fixed point decimal value. The value is stored as an integer, and the
    /// precision is stored as a uint8. The value is multiplied by 10^precision to get the actual value.
    struct Dec {
        uint256 value;
        uint8 precision;
    }

    /// @dev Coin is a struct that represents a token with a denomination and an amount.
    struct Coin {
        string denom;
        uint256 amount;
    }

    /// @dev DecCoin is a struct that represents a token with a denomination, an amount and a precision.
    struct DecCoin {
        string denom;
        uint256 amount;
        uint8 precision;
    }

    /// @dev PageResponse is a struct that represents a page response.
    struct PageResponse {
        bytes nextKey;
        uint64 total;
    }

    /// @dev PageRequest is a struct that represents a page request.
    struct PageRequest {
        bytes key;
        uint64 offset;
        uint64 limit;
        bool countTotal;
        bool reverse;
    }

    /// @dev Height is a monotonically increasing data type
    /// that can be compared against another Height for the purposes of updating and
    /// freezing clients
    ///
    /// Normally the RevisionHeight is incremented at each height while keeping
    /// RevisionNumber the same. However some consensus algorithms may choose to
    /// reset the height in certain conditions e.g. hard forks, state-machine
    /// breaking changes In these cases, the RevisionNumber is incremented so that
    /// height continues to be monotonically increasing even as the RevisionHeight
    /// gets reset
    struct Height {
        // the revision that the client is currently on
        uint64 revisionNumber;
        // the height within the given revision
        uint64 revisionHeight;
    }

    // BondStatus is the status of a validator.
    enum BondStatus {
        Unspecified,
        Unbonded,
        Unbonding,
        Bonded
    }

    // Description contains a validator's description.
    struct Description {
        string moniker;
        string identity;
        string website;
        string securityContact;
        string details;
    }

    // CommissionRates defines the initial commission rates to be used for a validator
    struct CommissionRates {
        string rate;
        string maxRate;
        string maxChangeRate;
    }

    // Commission defines a commission parameters for a given validator.
    struct Commission {
        CommissionRates commissionRates;
        uint256 updateTime;
    }

    // Validator defines a validator, an account that can participate in consensus.
    struct Validator {
        string operatorAddress;
        string consensusPubkey;
        bool jailed;
        uint32 status;
        uint256 tokens;
        string delegatorShares;
        Description description;
        int64 unbondingHeight;
        uint256 unbondingTime;
        Commission commission;
        uint256 minSelfDelegation;
    }

    // Delegation represents the bond with tokens held by an account. It is
    // owned by one delegator, and is associated with the voting power of one
    // validator.
    struct Delegation {
        address delegatorAddress;
        string validatorAddress;
        string shares;
    }

    // UnbondingDelegation stores all of a single delegator's unbonding bonds
    // for a single validator in an array.
    struct UnbondingDelegation {
        address delegatorAddress;
        string validatorAddress;
        UnbondingDelegationEntry[] entries;
    }

    // UnbondingDelegationEntry defines an unbonding object with relevant metadata.
    struct UnbondingDelegationEntry {
        uint256 creationHeight;
        uint256 completionTime;
        string initialBalance;
        string balance;
    }

    // RedelegationEntry defines a redelegation object with relevant metadata.
    struct RedelegationEntry {
        uint256 creationHeight;
        uint256 completionTime;
        string initialBalance;
        string sharesDst;
    }

    // Redelegation contains the list of a particular delegator's redelegating bonds
    // from a particular source validator to a particular destination validator.
    struct Redelegation {
        address delegatorAddress;
        string validatorSrcAddress;
        string validatorDstAddress;
        RedelegationEntry[] entries;
    }

    // DelegationResponse is equivalent to Delegation except that it contains a
    // balance in addition to shares which is more suitable for client responses.
    struct DelegationResponse {
        Delegation delegation;
        Coin balance;
    }

    // RedelegationEntryResponse is equivalent to a RedelegationEntry except that it
    // contains a balance in addition to shares which is more suitable for client
    // responses.
    struct RedelegationEntryResponse {
        RedelegationEntry redelegationEntry;
        string balance;
    }

    // RedelegationResponse is equivalent to a Redelegation except that its entries
    // contain a balance in addition to shares which is more suitable for client
    // responses.
    struct RedelegationResponse {
        Redelegation redelegation;
        RedelegationEntryResponse[] entries;
    }

    // Pool is used for tracking bonded and not-bonded token supply of the bond denomination.
    struct Pool {
        string notBondedTokens;
        string bondedTokens;
    }

    // StakingParams defines the parameters for the staking module.
    struct Params {
        uint256 unbondingTime;
        uint256 maxValidators;
        uint256 maxEntries;
        uint256 historicalEntries;
        string bondDenom;
        string minCommissionRate;
    }

    event CreateValidator(string indexed validatorAddress, uint256 value);
    event EditValidator(string indexed validatorAddress);
    event Delegate(address indexed delegatorAddress, string indexed validatorAddress, uint256 amount);
    event Unbond(address indexed delegatorAddress, string indexed validatorAddress, uint256 amount, uint256 completionTime);
    event Redelegate(address indexed delegatorAddress, address indexed validatorSrcAddress, address indexed validatorDstAddress, uint256 amount, uint256 completionTime);
    event CancelUnbondingDelegation(address indexed delegatorAddress, address indexed validatorAddress, uint256 amount, uint256 creationHeight);

    // Transactions
    function createValidator(
        Description calldata description,
        CommissionRates calldata commission,
        uint256 minSelfDelegation,
        string calldata validatorAddress,
        string calldata pubkey,
        address value
    ) external payable returns (bool);

    function editValidator(
        Description calldata description,
        string calldata validatorAddress,
        uint256 commissionRate,
        uint256 minSelfDelegation
    ) external returns (bool);

    function delegate(
        address delegatorAddress,
        string calldata validatorAddress,
        uint256 amount
    ) external payable returns (bool);

    function undelegate(
        address delegatorAddress,
        string calldata validatorAddress,
        uint256 amount
    ) external returns (bool);

    function redelegate(
        address delegatorAddress,
        string calldata validatorSrcAddress,
        string calldata validatorDstAddress,
        uint256 amount
    ) external returns (bool);

    function cancelUnbondingDelegation(
        address delegatorAddress,
        string calldata validatorAddress,
        uint256 amount,
        uint256 creationHeight
    ) external returns (bool);

    // Queries
    function validator(
        string calldata validatorAddress
    ) external view returns (Validator memory);

    function validators(
        string calldata status,
        PageRequest calldata pageRequest
    ) external view returns (Validator[] memory, PageResponse memory);

    function delegation(
        address delegatorAddress,
        string calldata validatorAddress
    ) external view returns (uint256);

    function unbondingDelegation(
        address delegatorAddress,
        string calldata validatorAddress
    ) external view returns (UnbondingDelegation memory);

    function redelegation(
        address delegatorAddress,
        string calldata srcValidatorAddress,
        string calldata dstValidatorAddress
    ) external view returns (Redelegation memory);

    function redelegations(
        address delegatorAddress,
        string calldata srcValidatorAddress,
        string calldata dstValidatorAddress,
        PageRequest calldata pageRequest
    ) external view returns (RedelegationResponse[] memory, PageResponse memory);
    
}

contract stZETAMinterV203 is NativeMinterWithdrawal {

    string[] private allDelegations;

    address constant STAKING_CONTRACT = 0x0000000000000000000000000000000000000800;
    IStaking private staking = IStaking(STAKING_CONTRACT);

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstZETA", "unstZETA", BASE_URI) {
    }

    function _areEqual(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _addDelegation(string memory validator) internal {
        for (uint256 i = 0; i < allDelegations.length; i++) {
            if (_areEqual(allDelegations[i], validator)) {
                return; // already exists
            }
        }
        allDelegations.push(validator);
    }

    function _removeDelegation(string memory validator) internal {
        uint256 len = allDelegations.length;
        for (uint256 i = 0; i < len; i++) {
            if (_areEqual(allDelegations[i], validator)) {
                allDelegations[i] = allDelegations[len - 1];
                allDelegations.pop();
                break;
            }
        }
    }

    // Delegate tokens to a specific validator
    function delegate(string memory validator, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");
        bool success = staking.delegate(address(this), validator, amount);
        require(success, "Delegate failed");
        // Manage delegation list
        _addDelegation(validator);
    }

    // Undelegate tokens from a specific validator
    function undelegate(string memory validator, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        uint256 delegated = staking.delegation(address(this), validator);
        require(delegated >= amount, "Insufficient delegated amount");
        bool success = staking.undelegate(address(this), validator, amount);
        require(success, "Undelegate failed");
        // Remove validator if all tokens are unstaked
        if (amount == delegated) {
            _removeDelegation(validator);
        }
    }

    // Redelegate tokens from one validator to another
    function redelegate(string memory validatorSrc, string memory validatorDst, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        uint256 delegated = staking.delegation(address(this), validatorSrc);
        require(delegated >= amount, "Insufficient delegated amount");
        bool success = staking.redelegate(address(this), validatorSrc, validatorDst, amount);
        require(success, "Redelegate failed");
        // Manage delegation list
        if (amount == delegated) {
            _removeDelegation(validatorSrc);
        }
        _addDelegation(validatorDst);
    }

    // Read how much the contract has delegated to a specific validator
    function getDelegation(string calldata validator) public view returns (uint256) {
        // Call staking precompile
        uint256 delegated = staking.delegation(address(this), validator);
        return delegated;
    }

    // Disable withdrawals
    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

}