// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract stMANTAMinterWithdrawal is ERC20MinterWithdrawal {

    constructor(address _baseToken, address _stakingToken) ERC20MinterWithdrawal(_baseToken, _stakingToken, "unstMANTA", "unstMANTA") {
    }

}