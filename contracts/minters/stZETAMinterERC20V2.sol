// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../MinterV2.sol";

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

contract stZETAMinterERC20V2 is ERC20Minter {

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
    event Bridge(uint256 _amount);

    function updateDestination(address newDestination) public onlyOwner {
        destination = newDestination;
        emit UpdateDestination(newDestination);
    }

    function bridge(uint256 amount) public onlyOwner {
        require(amount > 0, "ZeroBridge");
        RevertOptions memory revertOptions = RevertOptions({
            revertAddress: address(this),
            callOnRevert: false,
            abortAddress: address(0),
            revertMessage: abi.encodePacked(""),
            onRevertGasLimit: 7000000
        });
        gateway.deposit(destination, amount, address(baseToken), revertOptions);
        emit Bridge(amount);
    }

}