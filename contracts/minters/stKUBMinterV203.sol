// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV203.sol";

interface IValidatorShare {
    function delegate() external payable;
    function undelegate(uint256 amount) external;
    function claimRewards() external;
    function getLiquidRewards(address delegator) external view returns (uint256);
    function getUnclaimedRewards(address delegator) external view returns (uint256);
    function balanceOf(address account) external view returns (uint256); // ERC-20 balance function
}

contract stKUBMinterV203 is NativeMinterWithdrawal {

    address[] private allDelegations;

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstKUB", "unstKUB", BASE_URI) {
    }

    function _beforeMint(uint256 amount) internal override {

        uint256 totalSupply = stakingToken.totalSupply();
        uint256 totalAssets = address(this).balance;

        for (uint256 i = 0; i < allDelegations.length; i++) {
            address delegation = allDelegations[i];

            // Base ERC20 balance
            uint256 balance = IValidatorShare(delegation).balanceOf(address(this));

            // Try getLiquidRewards(address)
            (bool success1, bytes memory data1) = delegation.call(
                abi.encodeWithSignature("getLiquidRewards(address)", address(this))
            );

            if (success1 && data1.length >= 32) {
                uint256 liquidRewards = abi.decode(data1, (uint256));
                totalAssets += balance + liquidRewards;
                continue; // no need to check unclaimed if liquid worked
            }

            // Otherwise, try getUnclaimedRewards(address)
            (bool success2, bytes memory data2) = delegation.call(
                abi.encodeWithSignature("getUnclaimedRewards(address)", address(this))
            );

            if (success2 && data2.length >= 32) {
                uint256 unclaimedRewards = abi.decode(data2, (uint256));
                totalAssets += balance + unclaimedRewards;
            } else {
                // fallback: only balance if neither reward function exists
                totalAssets += balance;
            }
        }
        
        require(totalSupply + amount <= totalAssets, "MintAmountExceeded");

    }

    function _areEqual(address a, address b) internal pure returns (bool) {
        return a == b;
    }

    function _addDelegation(address validator) internal {
        for (uint256 i = 0; i < allDelegations.length; i++) {
            if (_areEqual(allDelegations[i], validator)) {
                return; // already exists
            }
        }
        allDelegations.push(validator);
    }

    function _removeDelegation(address validator) internal {
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
    function delegate(address validator, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");
        // Call the validator's delegate function and forward KUB
        IValidatorShare(validator).delegate{value: amount}();
        // Manage delegation list
        _addDelegation(validator);
    }

    // Undelegate tokens from a specific validator
    function undelegate(address validator, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        uint256 delegated = getDelegatedAmount(validator);
        require(delegated >= amount, "Insufficient delegated amount");
        // Call the validator's undelegate function
        IValidatorShare(validator).undelegate(amount);

        // Remove validator if all tokens are unstaked
        if (amount == delegated) {
            _removeDelegation(validator);
        }
    }

    // Claim rewards from a specific validator
    function claimRewards(address validator) external onlyOwner {
        // Call the validator's claimRewards function
        IValidatorShare(validator).claimRewards();
    }

    // Get unclaimed rewards for a specific validator (old method)
    function getUnclaimedRewards(address validator) external view returns (uint256) {
        // Call the validator's getUnclaimedRewards function
        return IValidatorShare(validator).getUnclaimedRewards(address(this));
    }

    // Get unclaimed rewards for a specific validator (new method)
    function getLiquidRewards(address validator) external view returns (uint256) {
        // Call the validator's getUnclaimedRewards function
        return IValidatorShare(validator).getLiquidRewards(address(this));
    }

    // Get delegated amount for a specific validator
    function getDelegatedAmount(address validator) public view returns (uint256) {
        // Call the validator's balanceOf function to get the delegated amount
        return IValidatorShare(validator).balanceOf(address(this));
    }

    // Disable withdrawals
    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

}