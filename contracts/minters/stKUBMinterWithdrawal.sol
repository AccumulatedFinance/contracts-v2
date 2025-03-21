// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV201.sol";

interface IValidatorShare {
    function delegate() external payable;
    function undelegate(uint256 amount) external;
    function claimRewards() external;
    function getUnclaimedRewards(address delegator) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256); // ERC-20 balance function
}

contract stKUBMinterWithdrawal is NativeMinterWithdrawal {

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    // Array of validator contracts where tokens are delegated
    address[] public validators;

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstKUB", "unstKUB", BASE_URI) {
    }

    // Add a validator to the array
    function addValidator(address validator) external onlyOwner {
        validators.push(validator);
    }

    // Remove a validator from the array
    function removeValidator(address validator) external onlyOwner {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                validators[i] = validators[validators.length - 1];
                validators.pop();
                break;
            }
        }
    }

    // Delegate tokens to a specific validator
    function delegate(address validator, uint256 amount) external payable onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(isValidator(validator), "Invalid validator");
        require(msg.value == amount, "Incorrect Ether sent");

        // Call the validator's delegate function and forward the Ether
        IValidatorShare(validator).delegate{value: amount}();
    }

    // Undelegate tokens from a specific validator
    function undelegate(address validator, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(getDelegatedAmount(validator) >= amount, "Insufficient delegated amount");

        // Call the validator's undelegate function
        IValidatorShare(validator).undelegate(amount);
    }

    // Claim rewards from a specific validator
    function claimRewards(address validator) external onlyOwner {
        require(isValidator(validator), "Invalid validator");

        // Call the validator's claimRewards function
        IValidatorShare(validator).claimRewards();
    }

    // Get unclaimed rewards for a specific validator
    function getUnclaimedRewards(address validator) external view returns (uint256) {
        require(isValidator(validator), "Invalid validator");

        // Call the validator's getUnclaimedRewards function
        return IValidatorShare(validator).getUnclaimedRewards(address(this));
    }

    // Get delegated amount for a specific validator
    function getDelegatedAmount(address validator) public view returns (uint256) {
        require(isValidator(validator), "Invalid validator");

        // Call the validator's balanceOf function to get the delegated amount
        return IValidatorShare(validator).balanceOf(address(this));
    }

    // Check if an address is a valid validator
    function isValidator(address validator) internal view returns (bool) {
        for (uint256 i = 0; i < validators.length; i++) {
            if (validators[i] == validator) {
                return true;
            }
        }
        return false;
    }

    // Disable withdrawals (as per your original contract)
    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

}