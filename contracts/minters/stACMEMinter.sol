// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

// WACME bridge interface
interface IWACMEBridge {
    function burn(address token, string memory account, uint256 amount) external;
}

contract stACMEMinter is ERC20Minter {

    using SafeTransferLib for IERC20;

    // External bridge contract
    IWACMEBridge public bridge;

    // Staking account on Accumulate
    string public stakingAccount;

    constructor(address _baseToken, address _stakingToken, address _bridge, string memory _stakingAccount) ERC20Minter(_baseToken, _stakingToken, address(msg.sender)) {
        bridge = IWACMEBridge(_bridge);
        stakingAccount = _stakingAccount;
        // bridge can spend baseToken
        baseToken.approve(_bridge, type(uint256).max);
    }

    event UpdateStakingAccount(string _stakingAccount);

    function updateStakingAccount(string memory newStakingAccount) public onlyOwner {
        stakingAccount = newStakingAccount;
        emit UpdateStakingAccount(newStakingAccount);
    }

    function deposit(uint256 amount, address receiver) public override nonReentrant {
        require(amount > 0, "Deposit amount must be greater than 0");
        baseToken.safeTransferFrom(address(msg.sender), address(this), amount);
        bridge.burn(address(baseToken), stakingAccount, amount);
        stakingToken.mint(address(receiver), amount);
        emit Deposit(address(msg.sender), address(receiver), amount);
    }

}