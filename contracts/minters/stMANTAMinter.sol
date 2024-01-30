// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract stMANTAMinter is ERC20Minter {

    constructor(address _baseToken, address _stakingToken) ERC20Minter(_baseToken, _stakingToken) {
    }

}