// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract stVLXMinter is Minter {

    constructor(address _baseToken, address _stakingToken) Minter(_baseToken, _stakingToken, address(this)) {
    }

}