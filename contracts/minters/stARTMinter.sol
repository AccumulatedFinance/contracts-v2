// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV2.sol";

contract stARTMinterWithdrawal is NativeMinterWithdrawal {

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstART", "unstART", "https://api.accumulated.finance/v1/nft") {
    }

}