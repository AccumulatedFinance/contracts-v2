// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

/**
 * @title StakingAdmin
 * @notice Abstract contract for managing backup staking admin address and access control
 * @dev Provides stakingAdmin state and modifier for pluggable use in minter contracts
 */
abstract contract StakingAdmin {

    address public stakingAdmin; // Authorized stakingAdmin address

    event UpdateStakingAdmin(address indexed newStakingAdmin);

    /**
     * @notice Modifier for stakingAdmin-only access
     */
    modifier onlyStakingAdmin() {
        require(msg.sender == stakingAdmin, "NotStakingAdmin");
        _;
    }

    /**
     * @notice Initializes the stakingAdmin address
     */
    constructor() {
        stakingAdmin = msg.sender;
    }

    /**
     * @notice Updates the stakingAdmin address
     * @param newStakingAdmin New stakingAdmin address
     */
    function updateStakingAdmin(address newStakingAdmin) public onlyStakingAdmin {
        require(newStakingAdmin != address(0), "InvalidAddress");
        stakingAdmin = newStakingAdmin;
        emit UpdateStakingAdmin(newStakingAdmin);
    }
}