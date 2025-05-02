pragma solidity ^0.8.20;
abstract contract BaseLending is Ownable, ReentrancyGuard, ERC20 {
    using SafeTransferLib for IERC4626;
    string public constant VERSION = "v1.0.0";
    string public LENDING_TYPE = "base";
    IERC4626 public immutable collateral; // ERC4626 collateral token
    uint256 public totalDebtShares; // Total debt shares across all users
    uint256 public totalAssets; // Total asset deposited by suppliers (includes interest)
    uint256 public totalCollateral; // Total collateral deposited by borrowers
    uint256 public assetsCap; // Maximum allowed asset deposits (0 = no cap)
    mapping(address => uint256) internal userCollateral; // User's collateral (in wstTokens)
    mapping(address => uint256) internal userDebtShares; // User's debt shares
    uint256 internal debtPricePerShare = 10**18; // Price per debt share, increases with interest
    uint256 public constant SCALE_FACTOR = 10**18; // Scaling factor for 18 decimals
    uint256 public constant SECONDS_PER_YEAR = 31_536_000; // Seconds in a year
    uint256 public lastUpdateTimestamp; // Last interest update timestamp
    uint256 public constant BPS_DENOMINATOR = 10000; // Basis points denominator (100% = 10000 bps)
    uint256 public constant MAX_LTV = 9500; // 95% = 9500 bps
    uint256 public ltv = 0; // Default 0 (borrowing disabled), in bps
    uint256 public minBorrowingRate = 0;
    uint256 public vertexBorrowingRate = 1000;
    uint256 public maxBorrowingRate = 25000;
    uint256 public vertexUtilization = 9000;
    uint256 public stabilityFees;
    uint256 public constant MAX_STABILITY_FEE = 4500;
    uint256 public stabilityFee = 3000;
    address private liquidator; // Authorized liquidator address
    uint256 public liquidationBonus = 500; // 5% = 500 bps
    uint256 public constant MAX_LIQUIDATION_BONUS = 1000; // 10% = 1000 bps
    uint256 public constant LIQUIDATION_THRESHOLD = 1e18; // Health factor < 1
    mapping(address => uint256) internal baseBalances; // Unscaled balances
    uint256 internal baseTotalSupply; // Unscaled total supply
    event Deposit(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event Withdraw(address indexed caller, address indexed receiver, uint256 assets, uint256 shares);
    event DepositCollateral(address indexed user, uint256 amount);
    event WithdrawCollateral(address indexed user, uint256 amount);
    event Borrow(address indexed user, uint256 amount);
    event Repay(address indexed user, uint256 amount);
    event UpdateLTV(uint256 newLTV);
    event UpdateBorrowingRateParams(uint256 minRate, uint256 vertexRate, uint256 maxRate, uint256 vertexUtilization);
    event Recover(address indexed receiver, uint256 amount);
    event UpdateStabilityFee(uint256 newFee);
    event CollectStabilityFees(address indexed receiver, uint256 amount);
    event UpdateAssetsCap(uint256 newCap);
    event Liquidation(address indexed user, address indexed liquidator, uint256 debtCovered, uint256 collateralSeized);
    event UpdateLiquidator(address indexed newLiquidator);
    event UpdateLiquidationBonus(uint256 newBonus);
    event InterestUpdated(uint256 newDebtPricePerShare, uint256 lenderInterest, uint256 stabilityFee);
    modifier onlyLiquidator() {
        require(msg.sender == liquidator, "NotLiquidator");
        _;
    }
    constructor(IERC4626 _collateralToken) ERC20("AF Lending Pool Token", string(abi.encodePacked("afl", _collateralToken.symbol())), _collateralToken.decimals()) {
        collateral = _collateralToken;
        lastUpdateTimestamp = block.timestamp;
        liquidator = msg.sender;
    }
    function _getScaledLtv() internal view returns (uint256) {
        return (ltv * SCALE_FACTOR) / BPS_DENOMINATOR;
    }
    function _getPendingInterest(uint256 shares) private view returns (uint256) {
        if (shares == 0) return 0;
        uint256 currentDebtValue = (shares * getPricePerShareDebt()) / SCALE_FACTOR;
        uint256 principal = shares; // Initial debtPricePerShare was 1 * SCALE_FACTOR
        return currentDebtValue > principal ? currentDebtValue - principal : 0;
    }
    function getTotalPendingInterest() public view returns (uint256) {
        return _getPendingInterest(totalDebtShares);
    }
    function getUserPendingInterest(address user) public view returns (uint256) {
        return _getPendingInterest(userDebtShares[user]);
    }
    function getPricePerShare() public view returns (uint256) {
        if (baseTotalSupply == 0) return SCALE_FACTOR; // 1:1 initially
        uint256 grossInterest = getTotalPendingInterest();
        uint256 totalValue = totalAssets;
        if (grossInterest > 0) {
            uint256 stabilityFeeRate = _getStabilityFeeRate();
            uint256 fee = (grossInterest * stabilityFeeRate) / BPS_DENOMINATOR;
            totalValue += grossInterest - fee;
        }
        return (totalValue * SCALE_FACTOR) / baseTotalSupply;
    }
    function getPricePerShareDebt() public view returns (uint256) {
        if (totalDebtShares == 0) return SCALE_FACTOR; // 1:1 initially
        uint256 totalDebtValue = (totalDebtShares * debtPricePerShare) / SCALE_FACTOR;
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed == 0 || totalDebtValue == 0) return debtPricePerShare;
        uint256 rate = getBorrowingRate();
        uint256 scaledRate = (rate * SCALE_FACTOR) / BPS_DENOMINATOR;
        uint256 interest = (totalDebtValue * scaledRate * timeElapsed * SCALE_FACTOR) / (SCALE_FACTOR * SECONDS_PER_YEAR) / SCALE_FACTOR;
        uint256 interestFactor = (interest * SCALE_FACTOR) / totalDebtValue;
        return debtPricePerShare + (debtPricePerShare * interestFactor) / SCALE_FACTOR;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return (baseBalances[account] * getPricePerShare()) / SCALE_FACTOR;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return (baseTotalSupply * getPricePerShare()) / SCALE_FACTOR;
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        uint256 baseAmount = (amount * SCALE_FACTOR) / getPricePerShare();
        require(baseAmount <= baseBalances[msg.sender], "InsufficientBalance");
        baseBalances[msg.sender] -= baseAmount;
        baseBalances[recipient] += baseAmount;
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }
    function transferFrom(address sender, address receiver, uint256 amount) public virtual override returns (bool) {
        uint256 baseAmount = (amount * SCALE_FACTOR) / getPricePerShare();
        require(baseAmount <= baseBalances[sender], "InsufficientBalance");
        uint256 currentAllowance = allowance(sender, msg.sender);
        require(currentAllowance >= amount, "InsufficientAllowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        baseBalances[sender] -= baseAmount;
        baseBalances[receiver] += baseAmount;
        emit Transfer(sender, receiver, amount);
        return true;
    }
    function _mint(address account, uint256 amount) internal virtual override {
        require(account != address(0), "ERC20: mint to the zero address");
        _beforeTokenTransfer(address(0), account, amount);
        baseTotalSupply += amount;
        baseBalances[account] += amount;
        emit Transfer(address(0), account, (amount * getPricePerShare()) / SCALE_FACTOR);
        _afterTokenTransfer(address(0), account, amount);
    }
    function _burn(address account, uint256 amount) internal virtual override {
        require(account != address(0), "ERC20: burn from the zero address");
        require(baseBalances[account] >= amount, "ERC20: burn amount exceeds balance");
        _beforeTokenTransfer(account, address(0), amount);
        unchecked {
            baseTotalSupply -= amount;
            baseBalances[account] -= amount;
        }
        emit Transfer(account, address(0), (amount * getPricePerShare()) / SCALE_FACTOR);
        _afterTokenTransfer(address(0), account, amount);
    }
    function getVersion() public view virtual returns (string memory) {
        return string(abi.encodePacked(VERSION, ":", LENDING_TYPE));
    }
    function _getCollateralValue(address user) internal view returns (uint256) {
        return _getCollateralValueFromShares(userCollateral[user]);
    }
    function _getCollateralValueFromShares(uint256 shares) internal view returns (uint256) {
        return (shares * collateral.pricePerShare()) / SCALE_FACTOR;
    }
    function getMaxDebtForCollateral(uint256 collateralAmount) public view returns (uint256) {
        uint256 collateralValue = _getCollateralValueFromShares(collateralAmount);
        uint256 scaledLtv = _getScaledLtv();
        return (collateralValue * scaledLtv) / SCALE_FACTOR;
    }
    function getUtilizationRate() public view returns (uint256) {
        if (totalAssets == 0) return 0;
        uint256 totalDebtValue = (totalDebtShares * debtPricePerShare) / SCALE_FACTOR;
        return (totalDebtValue * BPS_DENOMINATOR) / totalAssets;
    }
    function getBorrowingRate() public view returns (uint256) {
        uint256 utilization = getUtilizationRate();
        if (utilization == vertexUtilization) {
            return vertexBorrowingRate;
        } else if (utilization < vertexUtilization) {
            uint256 rateDiff = vertexBorrowingRate - minBorrowingRate;
            return minBorrowingRate + (utilization * rateDiff) / vertexUtilization;
        } else {
            uint256 rateDiff = maxBorrowingRate - vertexBorrowingRate;
            uint256 utilDiff = utilization - vertexUtilization;
            uint256 utilRange = BPS_DENOMINATOR - vertexUtilization;
            return vertexBorrowingRate + (utilDiff * rateDiff) / utilRange;
        }
    }
    function getBorrowingRateParams() public view returns (
        uint256 minRate,
        uint256 vertexRate,
        uint256 maxRate,
        uint256 vertexUtil
    ) {
        return (minBorrowingRate, vertexBorrowingRate, maxBorrowingRate, vertexUtilization);
    }
    function _getStabilityFeeRate() internal view returns (uint256) {
        uint256 utilization = getUtilizationRate();
        if (utilization <= vertexUtilization) {
            return stabilityFee;
        } else {
            uint256 maxFee = stabilityFee * 2;
            uint256 feeDiff = maxFee - stabilityFee;
            uint256 utilDiff = utilization - vertexUtilization;
            uint256 utilRange = BPS_DENOMINATOR - vertexUtilization;
            return stabilityFee + (utilDiff * feeDiff) / utilRange;
        }
    }
    function getLendingRate() public view returns (uint256) {
        uint256 borrowingRate = getBorrowingRate();
        uint256 stabilityFeeRateInBps = _getStabilityFeeRate();
        uint256 utilization = getUtilizationRate();
        uint256 feeFactor = BPS_DENOMINATOR - stabilityFeeRateInBps;
        return (borrowingRate * utilization * feeFactor) / (BPS_DENOMINATOR * BPS_DENOMINATOR);
    }
    function getUserMaxBorrow(address user) public view returns (uint256) {
        uint256 userDebtValue = getUserDebtValue(user);
        uint256 maxDebt = getMaxDebtForCollateral(userCollateral[user]);
        return maxDebt > userDebtValue ? maxDebt - userDebtValue : 0;
    }
    function getUserCollateral(address user) public view returns (uint256) {
        return userCollateral[user];
    }
    function getUserDebtShares(address user) public view returns (uint256) {
        return userDebtShares[user];
    }
    function getUserDebtValue(address user) public view returns (uint256) {
        return (userDebtShares[user] * getPricePerShareDebt()) / SCALE_FACTOR;
    }
    function _updateInterest() internal {
        uint256 timeElapsed = block.timestamp - lastUpdateTimestamp;
        if (timeElapsed > 0 && totalDebtShares > 0) {
            uint256 borrowingRate = getBorrowingRate();
            uint256 scaledRate = (borrowingRate * SCALE_FACTOR) / BPS_DENOMINATOR;
            uint256 totalDebtValue = (totalDebtShares * debtPricePerShare) / SCALE_FACTOR;
            uint256 borrowingInterest = (totalDebtValue * scaledRate * timeElapsed * SCALE_FACTOR) / (SCALE_FACTOR * SECONDS_PER_YEAR) / SCALE_FACTOR;
            uint256 interestFactor = (borrowingInterest * SCALE_FACTOR) / totalDebtValue;
            debtPricePerShare = debtPricePerShare + (debtPricePerShare * interestFactor) / SCALE_FACTOR;
            uint256 stabilityFeeRate = _getStabilityFeeRate();
            uint256 fee = (borrowingInterest * stabilityFeeRate) / BPS_DENOMINATOR;
            uint256 lenderInterest = borrowingInterest - fee;
            totalAssets += lenderInterest;
            stabilityFees += fee;
            lastUpdateTimestamp = block.timestamp;
            emit InterestUpdated(debtPricePerShare, lenderInterest, fee);
        }
    }
    function depositCollateral(uint256 amount) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        collateral.safeTransferFrom(msg.sender, address(this), amount);
        userCollateral[msg.sender] += amount;
        totalCollateral += amount;
        emit DepositCollateral(msg.sender, amount);
    }
    function withdrawCollateral(uint256 amount) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        uint256 currentCollateral = userCollateral[msg.sender];
        require(currentCollateral >= amount, "InsufficientCollateral");
        uint256 remainingCollateral = currentCollateral - amount;
        uint256 userDebtValue = getUserDebtValue(msg.sender);
        require(userDebtValue <= getMaxDebtForCollateral(remainingCollateral), "InsufficientCollateral");
        userCollateral[msg.sender] = remainingCollateral;
        totalCollateral -= amount;
        collateral.safeTransfer(msg.sender, amount);
        emit WithdrawCollateral(msg.sender, amount);
    }
    function getUserCollateralValue(address user) public view returns (uint256) {
        return _getCollateralValue(user);
    }
    function getUserHealth(address user) public view returns (uint256) {
        // Health factor = (Collateral Value * LTV) / Debt
        uint256 borrowed = getUserDebtValue(user);
        if (borrowed == 0) return type(uint256).max;
        uint256 collateralValue = _getCollateralValue(user);
        uint256 scaledLtv = _getScaledLtv();
        return (collateralValue * scaledLtv) / borrowed;
    }
    function isLiquidatable(address user) public view returns (bool) {
        return getUserHealth(user) < LIQUIDATION_THRESHOLD;
    }
    function getUserMaxWithdrawCollateral(address user) public view returns (uint256) {
        uint256 borrowed = getUserDebtValue(user);
        if (borrowed == 0) return userCollateral[user];
        uint256 collateralShares = userCollateral[user];
        uint256 maxDebt = getMaxDebtForCollateral(collateralShares);
        if (borrowed >= maxDebt) return 0;
        uint256 excessValue = maxDebt - borrowed;
        uint256 pricePerShare = collateral.pricePerShare();
        require(pricePerShare > 0, "InvalidPrice");
        uint256 excessShares = (excessValue * SCALE_FACTOR) / pricePerShare;
        return excessShares > collateralShares ? collateralShares : excessShares;
    }
    function getRequiredAmountForLiquidation(address user, uint256 debtSharesToCover) public view returns (uint256) {
        require(debtSharesToCover <= userDebtShares[user], "InvalidDebtSharesAmount");
        return (debtSharesToCover * getPricePerShareDebt()) / SCALE_FACTOR;
    }
    function updateLTV(uint256 newLTV) public onlyOwner {
        require(newLTV <= MAX_LTV, "LTVExceedsMax");
        ltv = newLTV;
        emit UpdateLTV(newLTV);
    }
    function updateBorrowingRateParams(
        uint256 newMinRate,
        uint256 newVertexRate,
        uint256 newMaxRate,
        uint256 newVertexUtilization
    ) public onlyOwner {
        _updateInterest();
        require(newMinRate <= newVertexRate && newVertexRate <= newMaxRate, "InvalidRateOrder");
        require(newVertexUtilization > 0 && newVertexUtilization < BPS_DENOMINATOR, "InvalidVertexUtilization");
        minBorrowingRate = newMinRate;
        vertexBorrowingRate = newVertexRate;
        maxBorrowingRate = newMaxRate;
        vertexUtilization = newVertexUtilization;
        emit UpdateBorrowingRateParams(newMinRate, newVertexRate, newMaxRate, newVertexUtilization);
    }
    function updateStabilityFee(uint256 newFee) public onlyOwner {
        _updateInterest();
        require(newFee <= MAX_STABILITY_FEE, "FeeExceedsMax");
        stabilityFee = newFee;
        emit UpdateStabilityFee(newFee);
    }
    function updateAssetsCap(uint256 newCap) public onlyOwner {
        require(newCap >= totalAssets, "NewMaxBelowCurrentAssets");
        assetsCap = newCap;
        emit UpdateAssetsCap(newCap);
    }
    function updateLiquidator(address newLiquidator) public onlyOwner {
        require(newLiquidator != address(0), "InvalidAddress");
        liquidator = newLiquidator;
        emit UpdateLiquidator(newLiquidator);
    }
    function updateLiquidationBonus(uint256 newBonus) public onlyOwner {
        require(newBonus <= MAX_LIQUIDATION_BONUS, "BonusExceedsMax");
        liquidationBonus = newBonus;
        emit UpdateLiquidationBonus(newBonus);
    }
}
contract NativeLending is BaseLending {
    using SafeTransferLib for IERC4626;
    constructor(IERC4626 _collateralToken) BaseLending(_collateralToken) {
        LENDING_TYPE = "native";
    }
    function getUserMaxWithdraw(address user) public view returns (uint256) {
        uint256 userBalance = balanceOf(user);
        uint256 maxAvailable = address(this).balance;
        return userBalance < maxAvailable ? userBalance : maxAvailable;
    }
    function deposit(address receiver) public payable virtual nonReentrant {
        _updateInterest();
        require(totalAssets + msg.value <= assetsCap, "ExceedsAssetsCap");
        uint256 baseTokens = (msg.value * SCALE_FACTOR) / getPricePerShare();
        totalAssets += msg.value;
        _mint(receiver, baseTokens);
        emit Deposit(msg.sender, receiver, msg.value, baseTokens);
    }
    function withdraw(uint256 amount, address receiver) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        require(amount <= balanceOf(msg.sender), "InsufficientBalance");
        require(totalAssets >= amount, "InsufficientPoolAssets");
        uint256 baseTokens = (amount * SCALE_FACTOR) / getPricePerShare();
        require(address(this).balance >= amount, "InsufficientContractBalance");
        totalAssets -= amount;
        _burn(msg.sender, baseTokens);
        SafeTransferLib.safeTransferETH(receiver, amount);
        emit Withdraw(msg.sender, receiver, amount, baseTokens);
    }
    function borrow(uint256 amount) public virtual nonReentrant {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        require(address(this).balance >= amount, "InsufficientBalance");
        require(amount <= getUserMaxBorrow(msg.sender), "InsufficientCollateral");
        uint256 newDebtShares = (amount * SCALE_FACTOR) / debtPricePerShare;
        userDebtShares[msg.sender] += newDebtShares;
        totalDebtShares += newDebtShares;
        SafeTransferLib.safeTransferETH(msg.sender, amount);
        emit Borrow(msg.sender, amount);
    }
    function repay() public payable virtual nonReentrant {
        _updateInterest();
        require(msg.value > 0, "ZeroAmount");
        uint256 shares = userDebtShares[msg.sender];
        require(shares > 0, "NoDebt");
        uint256 dpps = debtPricePerShare;
        uint256 totalDebtValue = (shares * dpps) / SCALE_FACTOR;
        uint256 repayment = msg.value > totalDebtValue ? totalDebtValue : msg.value;
        if (repayment == totalDebtValue) {
            totalDebtShares -= shares;
            userDebtShares[msg.sender] = 0;
        } else {
            uint256 sharesRepaid = (repayment * SCALE_FACTOR) / dpps;
            totalDebtShares -= sharesRepaid;
            userDebtShares[msg.sender] -= sharesRepaid;
        }
        if (msg.value > totalDebtValue) {
            SafeTransferLib.safeTransferETH(msg.sender, msg.value - totalDebtValue);
        }
        emit Repay(msg.sender, repayment);
    }
    function liquidate(address user, uint256 debtSharesToCover) public payable virtual onlyLiquidator nonReentrant {
        _updateInterest();
        require(isLiquidatable(user), "PositionNotLiquidatable");
        require(debtSharesToCover > 0 && debtSharesToCover <= userDebtShares[user], "InvalidDebtSharesAmount");
        uint256 debtToCover = (debtSharesToCover * getPricePerShareDebt()) / SCALE_FACTOR;
        uint256 collateralPricePerShare = collateral.pricePerShare();
        require(collateralPricePerShare > 0, "InvalidPrice");
        uint256 collateralValue = (userCollateral[user] * collateralPricePerShare) / SCALE_FACTOR;
        uint256 bonusAmount = (debtToCover * liquidationBonus) / BPS_DENOMINATOR;
        uint256 maxBonus = collateralValue > debtToCover ? collateralValue - debtToCover : 0;
        bonusAmount = bonusAmount > maxBonus ? maxBonus : bonusAmount;
        uint256 totalValueToSeize = debtToCover + bonusAmount;
        require(totalValueToSeize <= collateralValue, "InsufficientCollateralValue");
        uint256 collateralSharesToSeize = (totalValueToSeize * SCALE_FACTOR) / collateralPricePerShare;
        require(collateralSharesToSeize <= userCollateral[user], "InsufficientCollateralShares");
        require(msg.value >= debtToCover, "InsufficientAmount");
        if (msg.value > debtToCover) {
            uint256 refund = msg.value - debtToCover;
            SafeTransferLib.safeTransferETH(msg.sender, refund);
        }
        userDebtShares[user] -= debtSharesToCover;
        totalDebtShares -= debtSharesToCover;
        userCollateral[user] -= collateralSharesToSeize;
        totalCollateral -= collateralSharesToSeize;
        collateral.safeTransfer(msg.sender, collateralSharesToSeize);
        emit Liquidation(user, msg.sender, debtToCover, collateralSharesToSeize);
    }
    function collectStabilityFees(address receiver) public onlyOwner {
        _updateInterest();
        require(stabilityFees > 0, "NoFeesToCollect");
        uint256 contractBalance = address(this).balance;
        uint256 amountToCollect = stabilityFees > contractBalance ? contractBalance : stabilityFees;
        stabilityFees -= amountToCollect;
        SafeTransferLib.safeTransferETH(receiver, amountToCollect);
        emit CollectStabilityFees(receiver, amountToCollect);
    }
    function getRecoverableAmount() public view returns (uint256) {
        uint256 totalDebtValue = (totalDebtShares * getPricePerShareDebt()) / SCALE_FACTOR;
        uint256 requiredBalance = totalAssets > totalDebtValue ? totalAssets - totalDebtValue : 0;
        uint256 reservedBalance = requiredBalance + stabilityFees;
        return address(this).balance > reservedBalance ? address(this).balance - reservedBalance : 0;
    }
    function recover(uint256 amount, address receiver) public virtual onlyOwner {
        _updateInterest();
        require(amount > 0, "ZeroAmount");
        uint256 excessBalance = getRecoverableAmount();
        require(amount <= excessBalance, "AmountExceedsExcess");
        SafeTransferLib.safeTransferETH(receiver, amount);
        emit Recover(receiver, amount);
    }
}