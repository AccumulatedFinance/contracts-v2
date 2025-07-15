// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../MinterV201.sol";

interface IStakedAuroraVault {
    function getStAurPrice() external view returns (uint256);
    function deposit(uint256 _assets, address _receiver) external returns (uint256);
}

contract rstAURMinterRedeem is ERC20MinterRedeem, ERC20Restaking {

    using SafeTransferLib for IERC20;

    uint256 public constant LST_PRICE_PER_SHARE = 1e18; // denominator for IStakedAuroraVault.getStAurPrice()

    IStakedAuroraVault public externalMinter;

    constructor(address _originToken, address _baseToken, address _stakingToken) ERC20MinterRedeem(_baseToken, _stakingToken) ERC20Restaking(_originToken) {
        externalMinter = IStakedAuroraVault(_baseToken);
    }

    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

    function previewDeposit(uint256 amount) public view virtual override returns (uint256) {
        uint256 feeAmount = amount*depositFee/FEE_DENOMINATOR;
        uint256 netAmount = amount-feeAmount;
        // apply pricePerShare from lst
        uint256 pricePerShare = externalMinter.getStAurPrice();
        require(pricePerShare > 0, "ZeroPricePerShare");
        uint256 finalAmount = netAmount * pricePerShare / LST_PRICE_PER_SHARE;
        return finalAmount;
    }

    function previewRedeem(uint256 amount) public view virtual override returns (uint256) {
        uint256 feeAmount = amount*redeemFee/FEE_DENOMINATOR;
        uint256 netAmount = amount-feeAmount;
        // apply pricePerShare from lst
        uint256 pricePerShare = externalMinter.getStAurPrice();
        require(pricePerShare > 0, "ZeroPricePerShare");
        uint256 finalAmount = netAmount * LST_PRICE_PER_SHARE / pricePerShare;
        return finalAmount;
    }

    function depositOrigin(uint256 amount, address receiver) public virtual nonReentrant override {
        require(amount >= minDepositOrigin, "LessThanMin");
        uint256 mintAmount = previewDepositOrigin(amount);
        require(mintAmount > 0, "ZeroMintAmount");
        originToken.safeTransferFrom(address(msg.sender), address(this), amount);
        originToken.approve(address(externalMinter), amount);
        uint256 shares = externalMinter.deposit(amount, address(this));
        require(shares > 0, "ZeroShares");
        stakingToken.mint(receiver, mintAmount);
        emit DepositOrigin(address(msg.sender), receiver, amount);
    }

}