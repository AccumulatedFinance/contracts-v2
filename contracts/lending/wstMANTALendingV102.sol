// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.20;

import "../LendingV102.sol";

contract wstMANTALendingV102 is ERC20Lending {

    constructor(IERC20 _assetToken, IERC4626 _collateralToken, address _lsdMinter) ERC20Lending(_assetToken, _collateralToken, _lsdMinter) {}

}