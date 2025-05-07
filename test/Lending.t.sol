pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../contracts/Lending.sol";
// Mock ERC4626 for testing
contract MockERC4626 is ERC20 {
    uint256 public pricePerShareValue = 1e18; // 1:1 for simplicity

    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {
        _setupDecimals(decimals);
    }

    function decimals() public view virtual override returns (uint8) {
        return super.decimals();
    }

    function pricePerShare() public view returns (uint256) {
        return pricePerShareValue;
    }

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        shares = assets; // 1:1 for simplicity
        _mint(receiver, shares);
        return shares;
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function safeTransferFrom(address from, address to, uint256 amount) public {
        transferFrom(from, to, amount);
    }

    function safeTransfer(address to, uint256 amount) public {
        transfer(to, amount);
    }
}

// Mock ERC20 for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals) ERC20(name, symbol) {
        _setupDecimals(decimals);
    }

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }
}

contract LendingTests is Test {
    using SafeMath for uint256;

    NativeLending public nativeLending;
    ERC20Lending public erc20Lending;
    MockERC4626 public collateralToken;
    MockERC20 public assetToken;
    address public owner;
    address public user1;
    address public user2;
    address public liquidator;

    uint256 constant INITIAL_SUPPLY = 1000 ether;
    uint256 constant COLLATERAL_AMOUNT = 100 ether;
    uint256 constant DEPOSIT_AMOUNT = 50 ether;
    uint256 constant BORROW_AMOUNT = 30 ether;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        liquidator = address(0x3);

        // Deploy mock tokens
        collateralToken = new MockERC4626("Collateral Token", "COLL", 18);
        assetToken = new MockERC20("Asset Token", "ASSET", 18);

        // Deploy lending contracts
        nativeLending = new NativeLending(collateralToken);
        erc20Lending = new ERC20Lending(assetToken, collateralToken);

        // Mint initial tokens
        collateralToken.mint(user1, INITIAL_SUPPLY);
        collateralToken.mint(user2, INITIAL_SUPPLY);
        assetToken.mint(user1, INITIAL_SUPPLY);
        assetToken.mint(user2, INITIAL_SUPPLY);

        // Set liquidator
        nativeLending.updateLiquidator(liquidator);
        erc20Lending.updateLiquidator(liquidator);

        // Approve tokens for ERC20Lending
        vm.startPrank(user1);
        assetToken.approve(address(erc20Lending), type(uint256).max);
        collateralToken.approve(address(erc20Lending), type(uint256).max);
        collateralToken.approve(address(nativeLending), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        assetToken.approve(address(erc20Lending), type(uint256).max);
        collateralToken.approve(address(erc20Lending), type(uint256).max);
        collateralToken.approve(address(nativeLending), type(uint256).max);
        vm.stopPrank();
    }

    // Helper function to deposit collateral
    function depositCollateral(BaseLending lending, address user, uint256 amount) internal {
        vm.startPrank(user);
        lending.depositCollateral(amount);
        vm.stopPrank();
    }

    // Helper function to deposit assets
    function depositAssetsNative(address user, uint256 amount, address receiver) internal {
        vm.deal(user, amount);
        vm.startPrank(user);
        nativeLending.deposit{value: amount}(receiver);
        vm.stopPrank();
    }

    function depositAssetsERC20(address user, uint256 amount, address receiver) internal {
        vm.startPrank(user);
        erc20Lending.deposit(amount, receiver);
        vm.stopPrank();
    }

    // Test getVersion
    function testGetVersion() public {
        assertEq(nativeLending.getVersion(), "v1.0.0:native");
        assertEq(erc20Lending.getVersion(), "v1.0.0:erc20");
    }

    // Test depositCollateral
    function testDepositCollateral() public {
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        assertEq(nativeLending.getUserCollateral(user1), COLLATERAL_AMOUNT);
        assertEq(nativeLending.totalCollateral(), COLLATERAL_AMOUNT);

        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        assertEq(erc20Lending.getUserCollateral(user1), COLLATERAL_AMOUNT);
        assertEq(erc20Lending.totalCollateral(), COLLATERAL_AMOUNT);
    }

    function testDepositCollateralZeroAmount() public {
        vm.expectRevert("ZeroAmount");
        depositCollateral(nativeLending, user1, 0);
        vm.expectRevert("ZeroAmount");
        depositCollateral(erc20Lending, user1, 0);
    }

    // Test withdrawCollateral
    function testWithdrawCollateral() public {
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        nativeLending.withdrawCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        assertEq(nativeLending.getUserCollateral(user1), 0);
        assertEq(nativeLending.totalCollateral(), 0);

        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        erc20Lending.withdrawCollateral(COLLATERAL_AMOUNT);
        vm.stopPrank();
        assertEq(erc20Lending.getUserCollateral(user1), 0);
        assertEq(erc20Lending.totalCollateral(), 0);
    }

    function testWithdrawCollateralInsufficient() public {
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        vm.expectRevert("InsufficientCollateral");
        nativeLending.withdrawCollateral(COLLATERAL_AMOUNT + 1);
        vm.stopPrank();

        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        vm.expectRevert("InsufficientCollateral");
        erc20Lending.withdrawCollateral(COLLATERAL_AMOUNT + 1);
        vm.stopPrank();
    }

    // Test deposit
    function testDepositNative() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        assertEq(nativeLending.balanceOf(user1), DEPOSIT_AMOUNT);
        assertEq(nativeLending.totalAssets(), DEPOSIT_AMOUNT);
    }

    function testDepositERC20() public {
        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        assertEq(erc20Lending.balanceOf(user1), DEPOSIT_AMOUNT);
        assertEq(erc20Lending.totalAssets(), DEPOSIT_AMOUNT);
    }

    function testDepositZeroAmount() public {
        vm.deal(user1, DEPOSIT_AMOUNT);
        vm.startPrank(user1);
        vm.expectRevert("ZeroAmount");
        nativeLending.deposit{value: 0}(user1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("ZeroAmount");
        erc20Lending.deposit(0, user1);
        vm.stopPrank();
    }

    // Test withdraw
    function testWithdrawNative() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        uint256 balanceBefore = user1.balance;
        vm.startPrank(user1);
        nativeLending.withdraw(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
        assertEq(nativeLending.balanceOf(user1), 0);
        assertEq(nativeLending.totalAssets(), 0);
        assertEq(user1.balance, balanceBefore + DEPOSIT_AMOUNT);
    }

    function testWithdrawERC20() public {
        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        uint256 balanceBefore = assetToken.balanceOf(user1);
        vm.startPrank(user1);
        erc20Lending.withdraw(DEPOSIT_AMOUNT, user1);
        vm.stopPrank();
        assertEq(erc20Lending.balanceOf(user1), 0);
        assertEq(erc20Lending.totalAssets(), 0);
        assertEq(assetToken.balanceOf(user1), balanceBefore + DEPOSIT_AMOUNT);
    }

    function testWithdrawInsufficientBalance() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        vm.startPrank(user1);
        vm.expectRevert("InsufficientBalance");
        nativeLending.withdraw(DEPOSIT_AMOUNT + 1, user1);
        vm.stopPrank();

        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        vm.startPrank(user1);
        vm.expectRevert("InsufficientBalance");
        erc20Lending.withdraw(DEPOSIT_AMOUNT + 1, user1);
        vm.stopPrank();
    }

    // Test borrow
    function testBorrowNative() public {
        nativeLending.updateLTV(5000); // 50% LTV
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        uint256 balanceBefore = user1.balance;
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        assertEq(nativeLending.getUserDebtValue(user1), BORROW_AMOUNT);
        assertEq(user1.balance, balanceBefore + BORROW_AMOUNT);
    }

    function testBorrowERC20() public {
        erc20Lending.updateLTV(5000); // 50% LTV
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        uint256 balanceBefore = assetToken.balanceOf(user1);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        assertEq(erc20Lending.getUserDebtValue(user1), BORROW_AMOUNT);
        assertEq(assetToken.balanceOf(user1), balanceBefore + BORROW_AMOUNT);
    }

    function testBorrowInsufficientCollateral() public {
        nativeLending.updateLTV(5000); // 50% LTV
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        vm.expectRevert("InsufficientCollateral");
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();

        erc20Lending.updateLTV(5000); // 50% LTV
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        vm.expectRevert("InsufficientCollateral");
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
    }

    // Test repay
    function testRepayNative() public {
        nativeLending.updateLTV(5000); // 50% LTV
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.deal(user1, BORROW_AMOUNT);
        nativeLending.repay{value: BORROW_AMOUNT}();
        vm.stopPrank();
        assertEq(nativeLending.getUserDebtValue(user1), 0);
        assertEq(nativeLending.totalDebtShares(), 0);
    }

    function testRepayERC20() public {
        erc20Lending.updateLTV(5000); // 50% LTV
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        erc20Lending.repay(BORROW_AMOUNT);
        vm.stopPrank();
        assertEq(erc20Lending.getUserDebtValue(user1), 0);
        assertEq(erc20Lending.totalDebtShares(), 0);
    }

    function testRepayNoDebt() public {
        vm.deal(user1, BORROW_AMOUNT);
        vm.startPrank(user1);
        vm.expectRevert("NoDebt");
        nativeLending.repay{value: BORROW_AMOUNT}();
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("NoDebt");
        erc20Lending.repay(BORROW_AMOUNT);
        vm.stopPrank();
    }

    // Test liquidate
    function testLiquidateNative() public {
        nativeLending.updateLTV(5000); // 50% LTV
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        // Simulate price drop to make position liquidatable
        collateralToken.pricePerShareValue = 0.5e18; // 50% price drop
        assertTrue(nativeLending.isLiquidatable(user1));
        uint256 debtShares = nativeLending.getUserDebtShares(user1);
        vm.deal(liquidator, BORROW_AMOUNT);
        vm.startPrank(liquidator);
        nativeLending.liquidate{value: BORROW_AMOUNT}(user1, debtShares);
        vm.stopPrank();
        assertEq(nativeLending.getUserDebtShares(user1), 0);
        assertEq(nativeLending.getUserCollateral(user1), 0);
    }

    function testLiquidateERC20() public {
        erc20Lending.updateLTV(5000); // 50% LTV
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        // Simulate price drop
        collateralToken.pricePerShareValue = 0.5e18; // 50% price drop
        assertTrue(erc20Lending.isLiquidatable(user1));
        uint256 debtShares = erc20Lending.getUserDebtShares(user1);
        vm.startPrank(liquidator);
        assetToken.approve(address(erc20Lending), BORROW_AMOUNT);
        erc20Lending.liquidate(user1, debtShares, BORROW_AMOUNT);
        vm.stopPrank();
        assertEq(erc20Lending.getUserDebtShares(user1), 0);
        assertEq(erc20Lending.getUserCollateral(user1), 0);
    }

    function testLiquidateNotLiquidatable() public {
        nativeLending.updateLTV(5000); // 50% LTV
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 debtShares = nativeLending.getUserDebtShares(user1);
        vm.deal(liquidator, BORROW_AMOUNT);
        vm.startPrank(liquidator);
        vm.expectRevert("PositionNotLiquidatable");
        nativeLending.liquidate{value: BORROW_AMOUNT}(user1, debtShares);
        vm.stopPrank();

        erc20Lending.updateLTV(5000); // 50% LTV
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        debtShares = erc20Lending.getUserDebtShares(user1);
        vm.startPrank(liquidator);
        vm.expectRevert("PositionNotLiquidatable");
        erc20Lending.liquidate(user1, debtShares, BORROW_AMOUNT);
        vm.stopPrank();
    }

    // Test updateLTV
    function testUpdateLTV() public {
        nativeLending.updateLTV(6000);
        assertEq(nativeLending.ltv(), 6000);
        erc20Lending.updateLTV(6000);
        assertEq(erc20Lending.ltv(), 6000);
    }

    function testUpdateLTVExceedsMax() public {
        vm.expectRevert("LTVExceedsMax");
        nativeLending.updateLTV(9501);
        vm.expectRevert("LTVExceedsMax");
        erc20Lending.updateLTV(9501);
    }

    // Test updateBorrowingRateParams
    function testUpdateBorrowingRateParams() public {
        nativeLending.updateBorrowingRateParams(500, 1500, 2000, 8000);
        (uint256 minRate, uint256 vertexRate, uint256 maxRate, uint256 vertexUtil) = nativeLending.getBorrowingRateParams();
        assertEq(minRate, 500);
        assertEq(vertexRate, 1500);
        assertEq(maxRate, 2000);
        assertEq(vertexUtil, 8000);

        erc20Lending.updateBorrowingRateParams(500, 1500, 2000, 8000);
        (minRate, vertexRate, maxRate, vertexUtil) = erc20Lending.getBorrowingRateParams();
        assertEq(minRate, 500);
        assertEq(vertexRate, 1500);
        assertEq(maxRate, 2000);
        assertEq(vertexUtil, 8000);
    }

    function testUpdateBorrowingRateParamsInvalid() public {
        vm.expectRevert("InvalidRateOrder");
        nativeLending.updateBorrowingRateParams(1500, 1000, 2000, 8000);
        vm.expectRevert("InvalidRateOrder");
        erc20Lending.updateBorrowingRateParams(1500, 1000, 2000, 8000);

        vm.expectRevert("InvalidVertexUtilization");
        nativeLending.updateBorrowingRateParams(500, 1500, 2000, 0);
        vm.expectRevert("InvalidVertexUtilization");
        erc20Lending.updateBorrowingRateParams(500, 1500, 2000, 0);
    }

    // Test updateStabilityFee
    function testUpdateStabilityFee() public {
        nativeLending.updateStabilityFee(4000);
        assertEq(nativeLending.stabilityFee(), 4000);
        erc20Lending.updateStabilityFee(4000);
        assertEq(erc20Lending.stabilityFee(), 4000);
    }

    function testUpdateStabilityFeeExceedsMax() public {
        vm.expectRevert("FeeExceedsMax");
        nativeLending.updateStabilityFee(4501);
        vm.expectRevert("FeeExceedsMax");
        erc20Lending.updateStabilityFee(4501);
    }

    // Test updateAssetsCap
    function testUpdateAssetsCap() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        nativeLending.updateAssetsCap(DEPOSIT_AMOUNT + 10 ether);
        assertEq(nativeLending.assetsCap(), DEPOSIT_AMOUNT + 10 ether);

        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        erc20Lending.updateAssetsCap(DEPOSIT_AMOUNT + 10 ether);
        assertEq(erc20Lending.assetsCap(), DEPOSIT_AMOUNT + 10 ether);
    }

    function testUpdateAssetsCapBelowCurrent() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        vm.expectRevert("NewMaxBelowCurrentAssets");
        nativeLending.updateAssetsCap(DEPOSIT_AMOUNT - 1);

        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        vm.expectRevert("NewMaxBelowCurrentAssets");
        erc20Lending.updateAssetsCap(DEPOSIT_AMOUNT - 1);
    }

    // Test updateLiquidator
    function testUpdateLiquidator() public {
        address newLiquidator = address(0x4);
        nativeLending.updateLiquidator(newLiquidator);
        // Since liquidator is private, we test by attempting liquidation
        vm.startPrank(newLiquidator);
        nativeLending.updateLTV(5000);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        collateralToken.pricePerShareValue = 0.5e18;
        uint256 debtShares = nativeLending.getUserDebtShares(user1);
        vm.deal(newLiquidator, BORROW_AMOUNT);
        nativeLending.liquidate{value: BORROW_AMOUNT}(user1, debtShares);
        vm.stopPrank();

        erc20Lending.updateLiquidator(newLiquidator);
        vm.startPrank(newLiquidator);
        erc20Lending.updateLTV(5000);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        collateralToken.pricePerShareValue = 0.5e18;
        debtShares = erc20Lending.getUserDebtShares(user1);
        assetToken.approve(address(erc20Lending), BORROW_AMOUNT);
        erc20Lending.liquidate(user1, debtShares, BORROW_AMOUNT);
        vm.stopPrank();
    }

    function testUpdateLiquidatorInvalidAddress() public {
        vm.expectRevert("InvalidAddress");
        nativeLending.updateLiquidator(address(0));
        vm.expectRevert("InvalidAddress");
        erc20Lending.updateLiquidator(address(0));
    }

    // Test updateLiquidationBonus
    function testUpdateLiquidationBonus() public {
        nativeLending.updateLiquidationBonus(600);
        assertEq(nativeLending.liquidationBonus(), 600);
        erc20Lending.updateLiquidationBonus(600);
        assertEq(erc20Lending.liquidationBonus(), 600);
    }

    function testUpdateLiquidationBonusExceedsMax() public {
        vm.expectRevert("BonusExceedsMax");
        nativeLending.updateLiquidationBonus(1001);
        vm.expectRevert("BonusExceedsMax");
        erc20Lending.updateLiquidationBonus(1001);
    }

    // Test collectStabilityFees
    function testCollectStabilityFeesNative() public {
        nativeLending.updateLTV(5000);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        // Fast forward time to accrue fees
        vm.warp(block.timestamp + 365 days);
        nativeLending.collectStabilityFees(owner);
        assertTrue(nativeLending.stabilityFees() < DEPOSIT_AMOUNT); // Some fees collected
    }

    function testCollectStabilityFeesERC20() public {
        erc20Lending.updateLTV(5000);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        erc20Lending.collectStabilityFees(owner);
        assertTrue(erc20Lending.stabilityFees() < DEPOSIT_AMOUNT); // Some fees collected
    }

    // Test recover
    function testRecoverNative() public {
        // Send excess ETH to contract
        vm.deal(address(this), 10 ether);
        (bool sent, ) = address(nativeLending).call{value: 10 ether}("");
        require(sent, "Failed to send ETH");
        uint256 recoverable = nativeLending.getRecoverableAmount();
        assertEq(recoverable, 10 ether);
        uint256 balanceBefore = owner.balance;
        nativeLending.recover(10 ether, owner);
        assertEq(owner.balance, balanceBefore + 10 ether);
    }

    function testRecoverERC20() public {
        // Send excess tokens to contract
        assetToken.mint(address(erc20Lending), 10 ether);
        uint256 recoverable = erc20Lending.getRecoverableAmount();
        assertEq(recoverable, 10 ether);
        uint256 balanceBefore = assetToken.balanceOf(owner);
        erc20Lending.recover(10 ether, owner);
        assertEq(assetToken.balanceOf(owner), balanceBefore + 10 ether);
    }

    function testRecoverAmountExceedsExcess() public {
        vm.deal(address(this), 10 ether);
        (bool sent, ) = address(nativeLending).call{value: 10 ether}("");
        require(sent, "Failed to send ETH");
        vm.expectRevert("AmountExceedsExcess");
        nativeLending.recover(11 ether, owner);

        assetToken.mint(address(erc20Lending), 10 ether);
        vm.expectRevert("AmountExceedsExcess");
        erc20Lending.recover(11 ether, owner);
    }

    // Test view functions
    function testGetUserCollateralValue() public {
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        assertEq(nativeLending.getUserCollateralValue(user1), COLLATERAL_AMOUNT);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        assertEq(erc20Lending.getUserCollateralValue(user1), COLLATERAL_AMOUNT);
    }

    function testGetUserHealth() public {
        nativeLending.updateLTV(5000);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 health = nativeLending.getUserHealth(user1);
        assertApproxEqAbs(health, 1.6666e18, 1e15); // (100 * 0.5) / 30 ≈ 1.6666

        erc20Lending.updateLTV(5000);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        health = erc20Lending.getUserHealth(user1);
        assertApproxEqAbs(health, 1.6666e18, 1e15);
    }

    function testGetUserMaxWithdrawCollateral() public {
        nativeLending.updateLTV(5000);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 maxWithdraw = nativeLending.getUserMaxWithdrawCollateral(user1);
        assertApproxEqAbs(maxWithdraw, 40 ether, 1e15); // 100 - (30 / 0.5) = 40

        erc20Lending.updateLTV(5000);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        maxWithdraw = erc20Lending.getUserMaxWithdrawCollateral(user1);
        assertApproxEqAbs(maxWithdraw, 40 ether, 1e15);
    }

    function testGetRequiredAmountForLiquidation() public {
        nativeLending.updateLTV(5000);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 debtShares = nativeLending.getUserDebtShares(user1);
        uint256 required = nativeLending.getRequiredAmountForLiquidation(user1, debtShares);
        assertEq(required, BORROW_AMOUNT);

        erc20Lending.updateLTV(5000);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        debtShares = erc20Lending.getUserDebtShares(user1);
        required = erc20Lending.getRequiredAmountForLiquidation(user1, debtShares);
        assertEq(required, BORROW_AMOUNT);
    }

    function testGetUtilizationRate() public {
        nativeLending.updateLTV(5000);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 util = nativeLending.getUtilizationRate();
        assertEq(util, 6000); // (30 / 50) * 10000 = 6000 bps

        erc20Lending.updateLTV(5000);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        util = erc20Lending.getUtilizationRate();
        assertEq(util, 6000);
    }

    function testGetBorrowingRate() public {
        nativeLending.updateLTV(5000);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 rate = nativeLending.getBorrowingRate();
        assertApproxEqAbs(rate, 666, 1); // Linear interpolation: 0 + (6000/9000) * (1000-0) ≈ 666

        erc20Lending.updateLTV(5000);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        rate = erc20Lending.getBorrowingRate();
        assertApproxEqAbs(rate, 666, 1);
    }

    function testGetLendingRate() public {
        nativeLending.updateLTV(5000);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        uint256 lendingRate = nativeLending.getLendingRate();
        // Borrowing rate ≈ 666 bps, utilization = 6000 bps, fee = 3000 bps
        // (666 * 6000 * (10000-3000)) / (10000 * 10000) ≈ 280
        assertApproxEqAbs(lendingRate, 280, 10);

        erc20Lending.updateLTV(5000);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        lendingRate = erc20Lending.getLendingRate();
        assertApproxEqAbs(lendingRate, 280, 10);
    }

    function testGetPricePerShare() public {
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        assertEq(nativeLending.getPricePerShare(), 1e18);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        assertEq(erc20Lending.getPricePerShare(), 1e18);
    }

    function testGetPricePerShareDebt() public {
        assertEq(nativeLending.getPricePerShareDebt(), 1e18);
        assertEq(erc20Lending.getPricePerShareDebt(), 1e18);
    }

    function testGetTotalPendingInterest() public {
        nativeLending.updateLTV(5000);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        uint256 interest = nativeLending.getTotalPendingInterest();
        assertTrue(interest > 0);

        erc20Lending.updateLTV(5000);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        interest = erc20Lending.getTotalPendingInterest();
        assertTrue(interest > 0);
    }

    function testGetUserPendingInterest() public {
        nativeLending.updateLTV(5000);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        nativeLending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        uint256 interest = nativeLending.getUserPendingInterest(user1);
        assertTrue(interest > 0);

        erc20Lending.updateLTV(5000);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        vm.startPrank(user1);
        erc20Lending.borrow(BORROW_AMOUNT);
        vm.stopPrank();
        vm.warp(block.timestamp + 365 days);
        interest = erc20Lending.getUserPendingInterest(user1);
        assertTrue(interest > 0);
    }

    function testGetUserMaxWithdraw() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        assertEq(nativeLending.getUserMaxWithdraw(user1), DEPOSIT_AMOUNT);
        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        assertEq(erc20Lending.getUserMaxWithdraw(user1), DEPOSIT_AMOUNT);
    }

    function testGetUserMaxBorrow() public {
        nativeLending.updateLTV(5000);
        depositCollateral(nativeLending, user1, COLLATERAL_AMOUNT);
        depositAssetsNative(user2, DEPOSIT_AMOUNT, user2);
        uint256 maxBorrow = nativeLending.getUserMaxBorrow(user1);
        assertEq(maxBorrow, 50 ether); // 100 * 0.5 = 50

        erc20Lending.updateLTV(5000);
        depositCollateral(erc20Lending, user1, COLLATERAL_AMOUNT);
        depositAssetsERC20(user2, DEPOSIT_AMOUNT, user2);
        maxBorrow = erc20Lending.getUserMaxBorrow(user1);
        assertEq(maxBorrow, 50 ether);
    }

    function testBalanceOfAndTotalSupply() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        assertEq(nativeLending.balanceOf(user1), DEPOSIT_AMOUNT);
        assertEq(nativeLending.totalSupply(), DEPOSIT_AMOUNT);

        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        assertEq(erc20Lending.balanceOf(user1), DEPOSIT_AMOUNT);
        assertEq(erc20Lending.totalSupply(), DEPOSIT_AMOUNT);
    }

    function testTransfer() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        vm.startPrank(user1);
        nativeLending.transfer(user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
        assertEq(nativeLending.balanceOf(user1), 0);
        assertEq(nativeLending.balanceOf(user2), DEPOSIT_AMOUNT);

        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        vm.startPrank(user1);
        erc20Lending.transfer(user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
        assertEq(erc20Lending.balanceOf(user1), 0);
        assertEq(erc20Lending.balanceOf(user2), DEPOSIT_AMOUNT);
    }

    function testTransferFrom() public {
        depositAssetsNative(user1, DEPOSIT_AMOUNT, user1);
        vm.startPrank(user1);
        nativeLending.approve(user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
        vm.startPrank(user2);
        nativeLending.transferFrom(user1, user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
        assertEq(nativeLending.balanceOf(user1), 0);
        assertEq(nativeLending.balanceOf(user2), DEPOSIT_AMOUNT);

        depositAssetsERC20(user1, DEPOSIT_AMOUNT, user1);
        vm.startPrank(user1);
        erc20Lending.approve(user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
        vm.startPrank(user2);
        erc20Lending.transferFrom(user1, user2, DEPOSIT_AMOUNT);
        vm.stopPrank();
        assertEq(erc20Lending.balanceOf(user1), 0);
        assertEq(erc20Lending.balanceOf(user2), DEPOSIT_AMOUNT);
    }
}