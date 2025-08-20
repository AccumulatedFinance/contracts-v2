// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../MinterV2.sol";

interface IZetaInterfaces {
    /**
     * @dev Use SendInput to interact with the Connector: connector.send(SendInput)
     */
    struct SendInput {
        /// @dev Chain id of the destination chain. More about chain ids https://docs.zetachain.com/learn/glossary#chain-id
        uint256 destinationChainId;
        /// @dev Address receiving the message on the destination chain (expressed in bytes since it can be non-EVM)
        bytes destinationAddress;
        /// @dev Gas limit for the destination chain's transaction
        uint256 destinationGasLimit;
        /// @dev An encoded, arbitrary message to be parsed by the destination contract
        bytes message;
        /// @dev ZETA to be sent cross-chain + ZetaChain gas fees + destination chain gas fees (expressed in ZETA)
        uint256 zetaValueAndGas;
        /// @dev Optional parameters for the ZetaChain protocol
        bytes zetaParams;
    }
}

interface IZetaConnector {
    function send(IZetaInterfaces.SendInput calldata input) external;
}

contract stZETAMinterERC20 is ERC20Minter {

    using SafeTransferLib for IERC20;

    // External connector contract
    IZetaConnector public connector;

    // Destination account for bridging
    address public destination;

    constructor(address _baseToken, address _stakingToken, address _connector, address _destination) ERC20Minter(_baseToken, _stakingToken) {
        connector = IZetaConnector(_connector);
        destination = _destination;
        // connector can spend baseToken
        baseToken.approve(_connector, type(uint256).max);
    }

    event UpdateDestination(address _destination);
    event UpdateConnector(address _connector);
    event Bridge(uint256 _amount);

    function updateDestination(address newDestination) public onlyOwner {
        destination = newDestination;
        emit UpdateDestination(newDestination);
    }

    function updateConnector(address newConnector) public onlyOwner {
        connector = IZetaConnector(newConnector);
        // Grant approval for the new connector to spend baseToken
        baseToken.approve(newConnector, type(uint256).max);
        emit UpdateConnector(newConnector);
    }

    function deposit(uint256 amount, address receiver) public override nonReentrant {
        require(amount > 0, "ZeroDeposit");
        uint256 mintAmount = previewDeposit(amount);
        require(mintAmount > 0, "ZeroMintAmount");
        baseToken.safeTransferFrom(address(msg.sender), address(this), amount);
        stakingToken.mint(receiver, mintAmount);
        emit Deposit(address(msg.sender), receiver, amount);
    }

    function bridge(uint256 amount) public onlyOwner {
        require(amount > 0, "ZeroBridgeAmount");
        require(destination != address(0), "InvalidDestination");
        // Send the specified amount to the destination chain via the connector
        IZetaInterfaces.SendInput memory sendInput = IZetaInterfaces.SendInput({
            destinationChainId: 7001,
            destinationAddress: abi.encodePacked(destination),
            destinationGasLimit: 5000000,
            message: abi.encodePacked(""),
            zetaValueAndGas: amount,
            zetaParams: abi.encodePacked("")
        });
        connector.send(sendInput);
        emit Bridge(amount);
    }

}