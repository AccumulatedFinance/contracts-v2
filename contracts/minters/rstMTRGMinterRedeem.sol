// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract rstMTRGMinter is ERC20MinterRedeem {

    using SafeTransferLib for IERC20;

    constructor(address _baseToken, address _stakingToken) ERC20MinterRedeem(_baseToken, _stakingToken) {
    }

    function withdraw(address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

}