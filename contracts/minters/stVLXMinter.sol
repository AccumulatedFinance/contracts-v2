// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract stVLXMinter is NativeMinter {

    constructor(address _stakingToken) NativeMinter(_stakingToken) {
    }

}