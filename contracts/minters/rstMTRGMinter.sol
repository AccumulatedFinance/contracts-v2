// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

contract rstMTRGMinter is ERC20Minter {

    using SafeMath for uint256;
    using SafeTransferLib for IERC20;

    constructor(address _baseToken, address _stakingToken) ERC20Minter(_baseToken, _stakingToken) {
    }

    uint256 public redeemFee = 0; // possible fee to cover bridging costs
    uint256 public constant MAX_REDEEM_FEE = 200; // max redeem fee 200bp (2%)

    event UpdateRedeemFee(uint256 _redeemFee);
    event Redeem(address indexed caller, address indexed receiver, uint256 amount);

    function previewRedeem(uint256 amount) public view virtual returns (uint256) {
        uint256 feeAmount = amount.mul(redeemFee).div(FEE_DENOMINATOR);
        uint256 netAmount = amount.sub(feeAmount);
        return netAmount;
    }

    function updateRedeemFee(uint256 newFee) public onlyOwner {
        require(newFee <= MAX_DEPOSIT_FEE, ">MaxFee");
        redeemFee = newFee;
        emit UpdateRedeemFee(newFee);
    }

    function redeem(uint256 amount, address receiver) public nonReentrant {
        require(amount > 0, "ZeroRedeem");
        uint256 redeemAmount = previewRedeem(amount);
        require(redeemAmount > 0, "ZeroRedeemAmount");
        stakingToken.safeTransferFrom(address(msg.sender), address(this), amount);
        stakingToken.burn(amount);
        baseToken.safeTransferFrom(address(this), receiver, redeemAmount);
        emit Redeem(address(msg.sender), receiver, amount);
    }

    function withdraw(address receiver) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdraw function disabled for ", receiver)));
    }

}