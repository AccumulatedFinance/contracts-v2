// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../MinterV204.sol";

contract stCOTIMinterV204 is NativeMinterWithdrawal, NativeFlashLoan {

    string public BASE_URI = "https://api.accumulated.finance/v1/nft";

    constructor(address _stakingToken) NativeMinterWithdrawal(_stakingToken, "unstCOTI", "unstCOTI", BASE_URI) {
    }

    // -----------------------------
    // Deposit override (BLOCKED)
    // -----------------------------
    function deposit(address receiver)
        public
        payable
        virtual
        override
        notDuringFlashLoan
        returns (uint256 minted)
    {
        // Use NativeMinter logic
        minted = super.deposit(receiver);
    }

}