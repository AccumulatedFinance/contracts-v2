// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

struct RevertOptions {
    address revertAddress;
    bool callOnRevert;
    address abortAddress;
    bytes revertMessage;
    uint256 onRevertGasLimit;
}

interface IZetaGateway {
    function deposit(address receiver, uint256 amount, address asset, RevertOptions calldata revertOptions) external;
}

contract stZETAMinterERC20Gateway is ERC20Minter {

    using SafeTransferLib for IERC20;

    // External gateway contract
    IZetaGateway public gateway;

    // Destination account for bridging
    address public destination;

    constructor(address _baseToken, address _stakingToken, address _gateway, address _destination) ERC20Minter(_baseToken, _stakingToken) {
        gateway = IZetaGateway(_gateway);
        destination = _destination;
        // gateway can spend baseToken
        baseToken.approve(_gateway, type(uint256).max);
    }

    event UpdateDestination(address _destination);

    function updateDestination(address newDestination) public onlyOwner {
        destination = newDestination;
        emit UpdateDestination(newDestination);
    }

    function deposit(uint256 amount, address receiver) public override nonReentrant {
        require(amount > 0, "ZeroDeposit");
        uint256 mintAmount = previewDeposit(amount);
        require(mintAmount > 0, "ZeroMintAmount");
        baseToken.safeTransferFrom(address(msg.sender), address(this), amount);
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: false,
            abortAddress: destination,
            revertMessage: abi.encodePacked(""),
            onRevertGasLimit: 5000000
        });
        gateway.deposit(destination, amount, address(baseToken), revertOptions);
        stakingToken.mint(receiver, mintAmount);
        emit Deposit(address(msg.sender), receiver, amount);
    }

}