// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV201.sol";

library Cosmos {
    struct Coin {
        uint256 amount;
        string denom;
    }
}

contract CosmosTypes {
    function coin(Cosmos.Coin calldata) public pure {}
}

interface IStakingModule {
    /// @dev Defines a method for performing a delegation of coins from the to a validator.
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be delegated to the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the delegate was successful
    function delegate(
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for the caller to undelegate funds from a validator.
    /// @param validatorAddress The address of the validator
    /// @param amount The amount of the bond denomination to be undelegated from the validator.
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the undelegate was successful
    function undelegate(
        string memory validatorAddress,
        uint256 amount
    ) external returns (bool success);

    /// @dev Defines a method for performing a redelegation
    /// of coins from the caller and source validator to a destination validator.
    /// @param validatorSrcAddress The validator from which the redelegation is initiated
    /// @param validatorDstAddress The validator to which the redelegation is destined
    /// @param amount The amount of the bond denomination to be redelegated to the validator
    /// This amount should use the bond denomination precision stored in the bank metadata.
    /// @return success Whether or not the redelegate was successful
    function redelegate(
        string memory validatorSrcAddress,
        string memory validatorDstAddress,
        uint256 amount
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
    ) external view returns (uint256 shares, Cosmos.Coin calldata balance);


    /***************************************************************************
    * DISTRIBUTION                                                             * 
    ***************************************************************************/

    /// @dev Withdraw the rewards of a delegator from a validator
    /// @param validatorAddress The address of the validator
    /// @return amount The amount of Coin withdrawn
    function withdrawDelegatorRewards(
        string memory validatorAddress
    ) external returns (Cosmos.Coin[] calldata amount);

}

contract stINJMinterWithdrawal is NativeMinterWithdrawal {

    address constant stakingContract = 0x0000000000000000000000000000000000000066;
    IStakingModule public stakingModule;

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstINJ", "unstINJ", BASE_URI) {
        stakingModule = IStakingModule(stakingContract);
    }

    event Delegate(string indexed to, uint256 amount);
    event Undelegate(string indexed from, uint256 amount);
    event Redelegate(string indexed from, string indexed to, uint256 amount);
    event ClaimRewards(string indexed from, uint256 amount);

    // Delegate tokens to a specific validator
    function delegate(string memory to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");
        bool success = stakingModule.delegate(to, amount);
        require(success, "Delegation failed");
        emit Delegate(to, amount);
    }

    // Undelegate tokens from a specific validator
    function undelegate(string memory from, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        bool success = stakingModule.undelegate(from, amount);
        require(success, "Undelegation failed");
        emit Undelegate(from, amount);
    }

    // Redelegate tokens from a specific validator to another validator
    function redelegate(string memory from, string memory to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        bool success = stakingModule.redelegate(from, to, amount);
        require(success, "Redelegation failed");
        emit Redelegate(from, to, amount);
    }

    // Claim rewards from a specific validator
    function claimRewards(string memory from) external onlyOwner {
        Cosmos.Coin[] memory rewards = stakingModule.withdrawDelegatorRewards(from);
        require(rewards.length > 0, "No rewards withdrawn");
        emit ClaimRewards(from, rewards[0].amount);
    }

    // Get delegated amount for a specific validator
    function getDelegation(string memory validator) public view returns (uint256 shares, Cosmos.Coin memory balance) {
        (shares, balance) = stakingModule.delegation(address(this), validator);
        return (shares, balance);
    }

    // Disable withdrawals
    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

}