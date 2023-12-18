// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

interface IERC677 {
    function transferAndCall(address to, uint256 value, bytes memory data) external;
}

contract stVLXMinterBSC is ERC20Minter {

    using SafeTransferLib for IERC20;

    // ERC-677 baseToken
    IERC677 private baseTokenERC677;

    // External bridge contract
    address public bridge;

    // Destination account for bridging
    address public destination;

    constructor(address _baseToken, address _stakingToken, address _bridge, address _destination) ERC20Minter(_baseToken, _stakingToken) {
        baseTokenERC677 = IERC677(_baseToken);
        bridge = _bridge;
        destination = _destination;
        // baseToken can spend its tokens
        baseToken.approve(_baseToken, type(uint256).max);
    }

    event UpdateBridgeDestination(address _destination);

    function updateBridgeDestination(address newDestination) public onlyOwner {
        destination = newDestination;
        emit UpdateBridgeDestination(newDestination);
    }

    function deposit(uint256 amount, address receiver) public override nonReentrant {
        require(amount > 0, "ZeroDeposit");
        uint256 mintAmount = previewDeposit(amount);
        require(mintAmount > 0, "ZeroMintAmount");
        baseToken.safeTransferFrom(address(msg.sender), address(this), amount);
        baseTokenERC677.transferAndCall(address(bridge), amount, abi.encodePacked(destination));
        stakingToken.mint(receiver, mintAmount);
        emit Deposit(address(msg.sender), receiver, amount);
    }

}