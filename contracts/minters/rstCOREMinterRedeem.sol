// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../MinterV201.sol";

interface IStCoreMinter {
    function getCurrentExchangeRate() external view returns (uint256);
    function mint(address _validator) external payable;
}

contract rstCOREMinterRedeem is ERC20MinterRedeem, NativeRestaking {

    uint256 public constant EXCHANGE_RATE_DENOMINATOR = 1_000_000; // denominator for IStCoreMinter.getCurrentExchangeRate()

    IStCoreMinter public lstMinter;
    address public lstValidator;

    constructor(address _baseToken, address _stakingToken, address _lstMinter, address _lstValidator) ERC20MinterRedeem(_baseToken, _stakingToken) {
        lstMinter = IStCoreMinter(_lstMinter);
        lstValidator = _lstValidator;
    }

    function withdraw(uint256 /*amount*/, address /* receiver */) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdrawals disabled")));
    }

    function previewDeposit(uint256 amount) public view virtual override returns (uint256) {
        uint256 feeAmount = amount*depositFee/FEE_DENOMINATOR;
        uint256 netAmount = amount-feeAmount;        // apply exchangeRate from lst
        uint256 exchangeRate = lstMinter.getCurrentExchangeRate();
        uint256 mintAmount = netAmount * exchangeRate / EXCHANGE_RATE_DENOMINATOR;
        return mintAmount;
    }

    function depositOrigin(address receiver) public payable virtual nonReentrant override {
        require(msg.value >= minDepositOrigin, "LessThanMin");
        uint256 mintAmount = previewDepositOrigin(msg.value);
        require(mintAmount > 0, "ZeroMintAmount");
        lstMinter.mint{value: mintAmount}(lstValidator);
        stakingToken.mint(receiver, mintAmount);
        emit DepositOrigin(address(msg.sender), receiver, msg.value);
    }

}