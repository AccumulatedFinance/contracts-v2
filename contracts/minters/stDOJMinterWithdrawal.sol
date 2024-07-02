// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract stDOJMinterWithdrawal is NativeMinterWithdrawal {

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstDOJ", "unstDOJ") {
    }

}