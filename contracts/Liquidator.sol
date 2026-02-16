// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFlashLoanReceiver {
    function requestPayback(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
) external payable returns (bytes32);
}

interface INativeFlashLoan {
    function flashLoan(address receiver, uint256 amount, bytes calldata data) external returns (bool);
}

contract Liquidator is IFlashLoanReceiver {
    bytes32 public constant FLASHLOAN_CALLBACK_SUCCESS =
        keccak256("FLASHLOAN_CALLBACK_SUCCESS");

    address public immutable minter;

    constructor(address _minter) {
        minter = _minter;
    }

    // Step 1: user calls this to start the flashloan
    function executeFlashLoan(uint256 amount) external {
        INativeFlashLoan(minter).flashLoan(address(this), amount, "");
    }

    // Step 2: minter calls this and sends ETH
    function requestPayback(
        address initiator,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external payable returns (bytes32) {
        require(msg.sender == minter, "NotMinter");
        require(payable(address(this)).balance >= amount, "NoETHReceived");

        // ----------------------------
        // YOUR PROFIT LOGIC GOES HERE
        // ----------------------------
        // Example: do nothing

        // Step 3: repay loan + fee
        (bool ok,) = payable(minter).call{value: amount + fee}("");
        require(ok, "RepayFailed");

        return FLASHLOAN_CALLBACK_SUCCESS;
    }

    // Optional: allow contract to be funded so it can pay fees if needed
    receive() external payable {}
}
