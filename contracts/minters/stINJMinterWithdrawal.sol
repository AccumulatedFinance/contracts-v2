// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../Minter.sol";

contract stINJMinterWithdrawal is NativeMinterWithdrawal {

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstINJ", "unstINJ") {
    }

}