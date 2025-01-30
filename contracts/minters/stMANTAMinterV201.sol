// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV201.sol";

contract stMANTAMinterWithdrawal is ERC20MinterWithdrawal {

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    constructor(address _baseToken, address _stakingToken) ERC20MinterWithdrawal(_baseToken, _stakingToken, "unstMANTA", "unstMANTA", BASE_URI) {
    }

}