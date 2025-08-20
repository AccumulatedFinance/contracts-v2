// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../LendingV100.sol";

contract wstROSELendingV100 is NativeLending {

    constructor(IERC4626 _collateralToken) NativeLending(_collateralToken) {}

}