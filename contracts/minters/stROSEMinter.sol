// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

/**
 * @title SDK Subcall wrappers
 * @notice Interact with Oasis Runtime SDK modules from Sapphire.
 */
library Subcall {

    string private constant CONSENSUS_DELEGATE = "consensus.Delegate";
    string private constant CONSENSUS_UNDELEGATE = "consensus.Undelegate";

    /// Address of the SUBCALL precompile
    address internal constant SUBCALL =
        0x0100000000000000000000000000000000000103;

    /// Raised if the underlying subcall precompile does not succeed
    error SubcallError();

    error ConsensusUndelegateError(uint64 status, string data);
    error ConsensusDelegateError(uint64 status, string data);

    /// Name of token cannot be CBOR encoded with current functions
    error TokenNameTooLong();

    /**
     * @notice Submit a native message to the Oasis runtime layer. Messages
     * which re-enter the EVM module are forbidden: `evm.*`.
     * @param method Native message type.
     * @param body CBOR encoded body.
     * @return status Result of call.
     * @return data CBOR encoded result.
     */
    function subcall(string memory method, bytes memory body)
        internal
        returns (uint64 status, bytes memory data)
    {
        (bool success, bytes memory tmp) = SUBCALL.call(
            abi.encode(method, body)
        );

        if (!success) {
            revert SubcallError();
        }

        (status, data) = abi.decode(tmp, (uint64, bytes));
    }

    /**
     * @notice Generic method to call `{to:address, amount:uint128}`.
     * @param method Runtime SDK method name ('module.Action').
     * @param to Destination address.
     * @param value Amount specified.
     * @return status Non-zero on error.
     * @return data Module name on error.
     */
    function _subcallWithToAndAmount(
        string memory method,
        bytes21 to,
        uint128 value,
        bytes memory token
    ) internal returns (uint64 status, bytes memory data) {
        // Ensures prefix is in range of 0x40..0x57 (inclusive)
        if (token.length > 19) revert TokenNameTooLong();

        (status, data) = subcall(
            method,
            abi.encodePacked(
                hex"a262",
                "to",
                hex"55",
                to,
                hex"66",
                "amount",
                hex"8250",
                value,
                uint8(0x40 + token.length),
                token
            )
        );
    }

    /**
     * @notice Start the undelegation process of the given number of shares from
     * consensus staking account to runtime account.
     * @param from Consensus address which shares were delegated to.
     * @param shares Number of shares to withdraw back to us.
     */
    function consensusUndelegate(bytes21 from, uint128 shares) internal {
        (uint64 status, bytes memory data) = subcall(
            CONSENSUS_UNDELEGATE,
            abi.encodePacked( // CBOR encoded, {'from': x, 'shares': y}
                hex"a2", // map, 2 pairs
                // pair 1
                hex"64", // UTF-8 string, 4 bytes
                "from",
                hex"55", // 21 bytes
                from,
                // pair 2
                hex"66", // UTF-8 string, 6 bytes
                "shares",
                hex"50", // 128bit unsigned int (16 bytes)
                shares
            )
        );

        if (status != 0) {
            revert ConsensusUndelegateError(status, string(data));
        }
    }

    /**
     * @notice Delegate native token to consensus level.
     * @param to Consensus address shares are delegated to.
     * @param amount Native token amount (in wei).
     */
    function consensusDelegate(bytes21 to, uint128 amount)
        internal
        returns (bytes memory data)
    {
        uint64 status;

        (status, data) = _subcallWithToAndAmount(
            CONSENSUS_DELEGATE,
            to,
            amount,
            ""
        );

        if (status != 0) {
            revert ConsensusDelegateError(status, string(data));
        }
    }

}

contract stROSEMinter is NativeMinter {

    using SafeMath for uint256;
    using SafeTransferLib for IERC20;

    constructor(address _stakingToken) NativeMinter(_stakingToken) {
    }

    uint256 public redeemFee = 0; // possible fee to cover bridging costs
    uint256 public constant MAX_REDEEM_FEE = 500; // max redeem fee 500bp (5%)

    event UpdateRedeemFee(uint256 _redeemFee);
    event Delegate(bytes21 _to, uint128 _amount);
    event Undelegate(bytes21 _from, uint128 _shares);
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

    function delegate(bytes21 to, uint128 amount) public onlyOwner {
        require(amount > 0, "ZeroDelegate");
        Subcall.consensusDelegate(to, amount);
        emit Delegate(to, amount);
    }

    function undelegate(bytes21 from, uint128 shares) public onlyOwner {
        require(shares > 0, "ZeroUndelegate");
        Subcall.consensusUndelegate(from, shares);
        emit Undelegate(from, shares);
    }

    function redeem(uint256 amount, address receiver) public nonReentrant {
        require(amount > 0, "ZeroRedeem");
        uint256 redeemAmount = previewRedeem(amount);
        require(redeemAmount > 0, "ZeroRedeemAmount");
        stakingToken.safeTransferFrom(address(msg.sender), address(this), amount);
        stakingToken.burn(amount);
        SafeTransferLib.safeTransferETH(receiver, redeemAmount);
        emit Redeem(address(msg.sender), receiver, amount);
    }

    function withdraw(address receiver) public view onlyOwner override {
        revert(string(abi.encodePacked("Withdraw function disabled for ", receiver)));
    }

}