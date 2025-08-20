// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../LendingV101.sol";

contract wstZETALendingV101 is NativeLending {

    constructor(IERC4626 _collateralToken, address _lsdMinter) NativeLending(_collateralToken, _lsdMinter) {}

}