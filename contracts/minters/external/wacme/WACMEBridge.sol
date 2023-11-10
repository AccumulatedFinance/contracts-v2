// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
}

contract WACMEBridge {
    function burn(IERC20 token, string memory destination, uint256 amount) public {
        // Ensure the sender has approved this contract to spend the specified amount of the token
        require(token.transferFrom(msg.sender, address(this), amount), "Transfer failed");
    }
}