// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.4;

import "../Minter.sol";

/**
 * @title SDK Subcall wrappers
 * @notice Interact with Oasis Runtime SDK modules from Sapphire.
 */
library Subcall {
    string private constant CONSENSUS_WITHDRAW = "consensus.Withdraw";

    /// Address of the SUBCALL precompile
    address internal constant SUBCALL =
        0x0100000000000000000000000000000000000103;

    /// Raised if the underlying subcall precompile does not succeed
    error SubcallError();

    /// There was an error parsing the receipt
    error ConsensusWithdrawError(uint64 status, string data);

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
     * @notice Transfer from an account in this runtime to a consensus staking
     * account.
     * @param to Consensus address which gets the tokens.
     * @param value Token amount (in wei).
     */
    function consensusWithdraw(bytes21 to, uint128 value) internal {
        (uint64 status, bytes memory data) = _subcallWithToAndAmount(
            CONSENSUS_WITHDRAW,
            to,
            value,
            ""
        );

        if (status != 0) {
            revert ConsensusWithdrawError(status, string(data));
        }
    }
}

contract stROSEMinter is NativeMinter {
    
    // Staking account on Oasis Consensus
    bytes21 public stakingAccount;

    constructor(address _stakingToken, bytes21 _stakingAccount) NativeMinter(_stakingToken) {
        stakingAccount = _stakingAccount;
    }

    event UpdateStakingAccount(bytes21 _stakingAccount);

    function updateStakingAccount(bytes21 newStakingAccount) public onlyOwner {
        stakingAccount = newStakingAccount;
        emit UpdateStakingAccount(newStakingAccount);
    }

    function deposit(address receiver) public payable override nonReentrant {
        require(msg.value > 0, "ZeroDeposit");
        uint256 mintAmount = previewDeposit(msg.value);
        require(mintAmount > 0, "ZeroMintAmount");
        Subcall.consensusWithdraw(stakingAccount, uint128(msg.value));
        stakingToken.mint(receiver, uint128(mintAmount));
        emit Deposit(address(msg.sender), receiver, uint128(msg.value));
    }

}