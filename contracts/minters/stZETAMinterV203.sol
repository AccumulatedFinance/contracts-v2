// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV203.sol";
import "../MinterExtStakingAdmin.sol";

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

/// @dev Defines the initial description to be used for creating
/// a validator.
struct Description {
    string moniker;
    string identity;
    string website;
    string securityContact;
    string details;
}

/// @dev Defines the initial commission rates to be used for creating
/// a validator.
struct CommissionRates {
    uint256 rate;
    uint256 maxRate;
    uint256 maxChangeRate;
}

/// @dev Defines commission parameters for a given validator.
struct Commission {
    CommissionRates commissionRates;
    uint256 updateTime;
}

/// @dev Represents a validator in the staking module.
struct Validator {
    string operatorAddress;
    string consensusPubkey;
    bool jailed;
    BondStatus status;
    uint256 tokens;
    uint256 delegatorShares; // TODO: decimal
    string description;
    int64 unbondingHeight;
    int64 unbondingTime;
    uint256 commission;
    uint256 minSelfDelegation;
}

/// @dev Represents the output of a Redelegations query.
struct RedelegationResponse {
    Redelegation redelegation;
    RedelegationEntryResponse[] entries;
}

/// @dev Represents a redelegation between a delegator and a validator.
struct Redelegation {
    string delegatorAddress;
    string validatorSrcAddress;
    string validatorDstAddress;
    RedelegationEntry[] entries;
}

/// @dev Represents a RedelegationEntryResponse for the Redelegations query.
struct RedelegationEntryResponse {
    RedelegationEntry redelegationEntry;
    uint256 balance;
}

/// @dev Represents a single Redelegation entry.
struct RedelegationEntry {
    int64 creationHeight;
    int64 completionTime;
    uint256 initialBalance;
    uint256 sharesDst; // TODO: decimal
}

/// @dev Represents the output of the Redelegation query.
struct RedelegationOutput {
    string delegatorAddress;
    string validatorSrcAddress;
    string validatorDstAddress;
    RedelegationEntry[] entries;
}

/// @dev Represents a single entry of an unbonding delegation.
struct UnbondingDelegationEntry {
    int64 creationHeight;
    int64 completionTime;
    uint256 initialBalance;
    uint256 balance;
    uint64 unbondingId;
    int64 unbondingOnHoldRefCount;
}

/// @dev Represents the output of the UnbondingDelegation query.
struct UnbondingDelegationOutput {
    string delegatorAddress;
    string validatorAddress;
    UnbondingDelegationEntry[] entries;
}

/// @dev The status of the validator.
enum BondStatus {
    Unspecified,
    Unbonded,
    Unbonding,
    Bonded
}

/// @author Evmos Team
/// @title Staking Precompiled Contract
/// @dev The interface through which solidity contracts will interact with staking.
/// We follow this same interface including four-byte function selectors, in the precompile that
/// wraps the pallet.
/// @custom:address 0x0000000000000000000000000000000000000800
interface StakingI {
    /// @dev Defines a method for creating a new validator.
    /// @param description The initial description
    /// @param commissionRates The initial commissionRates
    /// @param minSelfDelegation The validator's self declared minimum self delegation
    /// @param validatorAddress The validator address
    /// @param pubkey The consensus public key of the validator
    /// @param value The amount of the coin to be self delegated to the validator
    /// @return success Whether or not the create validator was successful
    function createValidator(
        Description calldata description,
        CommissionRates calldata commissionRates,
        uint256 minSelfDelegation,
        address validatorAddress,
        string memory pubkey,
        uint256 value
    ) external returns (bool success);

    /// @dev Defines a method for edit a validator.
    /// @param description Description parameter to be updated. Use the string "[do-not-modify]"
    /// as the value of fields that should not be updated.
    /// @param commissionRate CommissionRate parameter to be updated.
    /// Use commissionRate = -1 to keep the current value and not update it.
    /// @param minSelfDelegation MinSelfDelegation parameter to be updated.
    /// Use minSelfDelegation = -1 to keep the current value and not update it.
    /// @return success Whether or not edit validator was successful.
    function editValidator(
        Description calldata description,
        address validatorAddress,
        int256 commissionRate,
        int256 minSelfDelegation
    ) external returns (bool success);

    /// @dev Defines a method for performing a delegation of coins from a delegator to a validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be delegated to the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the delegate was successful
    function delegate(
        address delegatorAddress,
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for performing an undelegation from a delegate and a validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be undelegated from the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return completionTime The time when the undelegation is completed
    function undelegate(
        address delegatorAddress,
        string memory validatorAddress,
        uint256 amount
    ) external returns (int64 completionTime);

    /// @dev Defines a method for performing a redelegation
    /// of coins from a delegator and source validator to a destination validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorSrcAddress The validator from which the redelegation is initiated
    /// @param validatorDstAddress The validator to which the redelegation is destined
    /// @param amount The amount of the bond denomination to be redelegated to the validator
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return completionTime The time when the redelegation is completed
    function redelegate(
        address delegatorAddress,
        string memory validatorSrcAddress,
        string memory validatorDstAddress,
        uint256 amount
    ) external returns (int64 completionTime);

    /// @dev Allows delegators to cancel the unbondingDelegation entry
    /// and to delegate back to a previous validator.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @param creationHeight The height at which the unbonding took place
    /// @return success Whether or not the unbonding delegation was cancelled
    function cancelUnbondingDelegation(
        address delegatorAddress,
        string memory validatorAddress,
        uint256 amount,
        uint256 creationHeight
    ) external returns (bool success);

    /// @dev Queries the given amount of the bond denomination to a validator.
    /// @param delegatorAddress The address of the delegator.
    /// @param validatorAddress The address of the validator.
    /// @return shares The amount of shares, that the delegator has received.
    /// @return balance The amount in Coin, that the delegator has delegated to the given validator.
    /// This returned balance uses the bond denomination precision stored in the bank metadata.
    function delegation(
        address delegatorAddress,
        string memory validatorAddress
    ) external view returns (uint256 shares, Coin calldata balance);

    /// @dev Returns the delegation shares and coins, that are currently
    /// unbonding for a given delegator and validator pair.
    /// @param delegatorAddress The address of the delegator.
    /// @param validatorAddress The address of the validator.
    /// @return unbondingDelegation The delegations that are currently unbonding.
    function unbondingDelegation(
        address delegatorAddress,
        string memory validatorAddress
    )
        external
        view
        returns (UnbondingDelegationOutput calldata unbondingDelegation);

    /// @dev Queries validator info for a given validator address.
    /// @param validatorAddress The address of the validator.
    /// @return validator The validator info for the given validator address.
    function validator(
        address validatorAddress
    ) external view returns (Validator calldata validator);

    /// @dev Queries all validators that match the given status.
    /// @param status Enables to query for validators matching a given status.
    /// @param pageRequest Defines an optional pagination for the request.
    function validators(
        string memory status,
        PageRequest calldata pageRequest
    )
        external
        view
        returns (
            Validator[] calldata validators,
            PageResponse calldata pageResponse
        );

    /// @dev Queries all redelegations from a source to a destination validator for a given delegator.
    /// @param delegatorAddress The address of the delegator.
    /// @param srcValidatorAddress Defines the validator address to redelegate from.
    /// @param dstValidatorAddress Defines the validator address to redelegate to.
    /// @return redelegation The active redelegations for the given delegator, source and destination
    /// validator combination.
    function redelegation(
        address delegatorAddress,
        string memory srcValidatorAddress,
        string memory dstValidatorAddress
    ) external view returns (RedelegationOutput calldata redelegation);

    /// @dev Queries all redelegations based on the specified criteria:
    /// for a given delegator and/or origin validator address
    /// and/or destination validator address
    /// in a specified pagination manner.
    /// @param delegatorAddress The address of the delegator as string (can be a zero address).
    /// @param srcValidatorAddress Defines the validator address to redelegate from (can be empty string).
    /// @param dstValidatorAddress Defines the validator address to redelegate to (can be empty string).
    /// @param pageRequest Defines an optional pagination for the request.
    /// @return response Holds the redelegations for the given delegator, source and destination validator combination.
    function redelegations(
        address delegatorAddress,
        string memory srcValidatorAddress,
        string memory dstValidatorAddress,
        PageRequest calldata pageRequest
    )
        external
        view
        returns (
            RedelegationResponse[] calldata response,
            PageResponse calldata pageResponse
        );

    /// @dev CreateValidator defines an Event emitted when a create a new validator.
    /// @param validatorAddress The address of the validator
    /// @param value The amount of coin being self delegated
    event CreateValidator(address indexed validatorAddress, uint256 value);

    /// @dev EditValidator defines an Event emitted when edit a validator.
    /// @param validatorAddress The address of the validator.
    /// @param commissionRate The commission rate.
    /// @param minSelfDelegation The min self delegation.
    event EditValidator(
        address indexed validatorAddress,
        int256 commissionRate,
        int256 minSelfDelegation
    );

    /// @dev Delegate defines an Event emitted when a given amount of tokens are delegated from the
    /// delegator address to the validator address.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of bond denomination being delegated
    /// This amount has the bond denomination precision stored in the bank metadata.
    /// @param newShares The new delegation shares being held
    event Delegate(
        address indexed delegatorAddress,
        address indexed validatorAddress,
        uint256 amount,
        uint256 newShares
    );

    /// @dev Unbond defines an Event emitted when a given amount of tokens are unbonded from the
    /// validator address to the delegator address.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of bond denomination being unbonded
    /// This amount has the bond denomination precision stored in the bank metadata.
    /// @param completionTime The time at which the unbonding is completed
    event Unbond(
        address indexed delegatorAddress,
        address indexed validatorAddress,
        uint256 amount,
        uint256 completionTime
    );

    /// @dev Redelegate defines an Event emitted when a given amount of tokens are redelegated from
    /// the source validator address to the destination validator address.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorSrcAddress The address of the validator from which the delegation is retracted
    /// @param validatorDstAddress The address of the validator to which the delegation is directed
    /// @param amount The amount of bond denomination being redelegated
    /// This amount has the bond denomination precision stored in the bank metadata.
    /// @param completionTime The time at which the redelegation is completed
    event Redelegate(
        address indexed delegatorAddress,
        address indexed validatorSrcAddress,
        address indexed validatorDstAddress,
        uint256 amount,
        uint256 completionTime
    );

    /// @dev CancelUnbondingDelegation defines an Event emitted when a given amount of tokens
    /// that are in the process of unbonding from the validator address are bonded again.
    /// @param delegatorAddress The address of the delegator
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of bond denomination that was in the unbonding process which is to be canceled
    /// This amount has the bond denomination precision stored in the bank metadata.
    /// @param creationHeight The block height at which the unbonding of a delegation was initiated
    event CancelUnbondingDelegation(
        address indexed delegatorAddress,
        address indexed validatorAddress,
        uint256 amount,
        uint256 creationHeight
    );
}

contract stZETAMinterV203 is NativeMinterWithdrawal, StakingAdmin {

    address constant STAKING_CONTRACT = 0x0000000000000000000000000000000000000800;
    StakingI private staking = StakingI(STAKING_CONTRACT);

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstZETA", "unstZETA", BASE_URI) StakingAdmin() {
    }

    // Delegate tokens to a specific validator
    function delegate(string memory validator, uint256 amount) external onlyOwner {
        require(amount > 0, "ZeroAmount");
        require(address(this).balance >= amount, "NotEnoughTokens");
        staking.delegate(address(this), validator, amount);
    }

    // Undelegate tokens from a specific validator
    function undelegate(string memory validator, uint256 amount) external onlyOwner {
        require(amount > 0, "ZeroAmount");
        staking.undelegate(address(this), validator, amount);
    }

    // Redelegate tokens from one validator to another
    function redelegate(string memory validatorSrc, string memory validatorDst, uint256 amount) external onlyOwner {
        require(amount > 0, "ZeroAmount");
        staking.redelegate(address(this), validatorSrc, validatorDst, amount);
    }

    // Undelegate tokens from a specific validator by staking admin
    function emergencyUndelegate(string memory validator, uint256 amount) external onlyStakingAdmin {
        require(amount > 0, "ZeroAmount");
        staking.undelegate(address(this), validator, amount);
    }

    // Returns number of shares delegated to a specific validator
    function delegation(string memory validator) public view returns (uint256 shares) {
        (shares, ) = staking.delegation(address(this), validator);
    }

    // Disable withdrawals
    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

}