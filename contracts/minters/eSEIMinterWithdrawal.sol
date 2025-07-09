// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV201.sol";

interface IStakingPrecompile {
    struct Delegation {
        Balance balance;
        DelegationDetails delegation;
    }

    struct Balance {
        uint256 amount;
        string denom;
    }

    struct DelegationDetails {
        string delegator_address;
        uint256 shares;
        uint256 decimals;
        string validator_address;
    }

    function delegate(string memory valAddress) external payable returns (bool success);
    function redelegate(string memory srcAddress, string memory dstAddress, uint256 amount) external returns (bool success);
    function undelegate(string memory valAddress, uint256 amount) external returns (bool success);
    function delegation(address delegator, string memory valAddress) external view returns (Delegation memory delegation);
}

contract eSEIMinterWithdrawal is NativeMinterWithdrawal {

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";
    IStakingPrecompile public staking = IStakingPrecompile(0x0000000000000000000000000000000000001005);

    string[] public allDelegations;

    event Delegate(string indexed validator, uint256 amount);
    event Redelegate(string indexed from, string indexed to, uint256 amount);
    event Undelegate(string indexed validator, uint256 amount);

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "uneSEI", "uneSEI", BASE_URI) {
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
        for (uint256 i = 0; i < allDelegations.length; i++) {
            if (_areEqual(allDelegations[i], validator)) {
                allDelegations[i] = allDelegations[allDelegations.length - 1];
                allDelegations.pop();
                break;
            }
        }
    }

    // Delegate tokens to a specific validator
    function delegate(string memory to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        require(address(this).balance >= amount, "Insufficient contract balance");
        bool success = staking.delegate{value: amount}(to);
        require(success, "Delegation failed");
        _addDelegation(to);
        emit Delegate(to, amount);
    }

    // Redelegate tokens to a specific validator
    function redelegate(string memory from, string memory to, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        IStakingPrecompile.Delegation memory d = staking.delegation(address(this), from);
        require(amount <= d.balance.amount, "Insufficient delegation amount");
        bool success = staking.redelegate(from, to, amount);
        require(success, "Redelegation failed");
        _addDelegation(to);
        // if all tokens were redelegated, remove delegation
        if (amount == d.balance.amount) {
            _removeDelegation(from);
        }
        emit Redelegate(from, to, amount);
    }

    // Undelegate tokens to a specific validator
    function undelegate(string memory from, uint256 amount) external onlyOwner {
        require(amount > 0, "Amount must be greater than 0");
        IStakingPrecompile.Delegation memory d = staking.delegation(address(this), from);
        require(amount <= d.balance.amount, "Insufficient delegation amount");
        bool success = staking.undelegate(from, amount);
        require(success, "Undelegation failed");
        // if all tokens were redelegated, remove delegation
        if (amount == d.balance.amount) {
            _removeDelegation(from);
        }
        emit Undelegate(from, amount);
    }

    // Disable withdrawals
    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

    // Query delegation information for a validator and this contract as delegator
    function getDelegation(string memory validator) external view returns (IStakingPrecompile.Delegation memory) {
        return staking.delegation(address(this), validator);
    }

    function getAllDelegations() external view returns (string[] memory) {
        return allDelegations;
    }

}