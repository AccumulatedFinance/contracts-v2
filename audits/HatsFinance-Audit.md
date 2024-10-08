# **Accumulated finance Audit Competition on Hats.finance** 


## Introduction to Hats.finance


Hats.finance builds autonomous security infrastructure for integration with major DeFi protocols to secure users' assets. 
It aims to be the decentralized choice for Web3 security, offering proactive security mechanisms like decentralized audit competitions and bug bounties. 
The protocol facilitates audit competitions to quickly secure smart contracts by having auditors compete, thereby reducing auditing costs and accelerating submissions. 
This aligns with their mission of fostering a robust, secure, and scalable Web3 ecosystem through decentralized security solutions​.

## About Hats Audit Competition


Hats Audit Competitions offer a unique and decentralized approach to enhancing the security of web3 projects. Leveraging the large collective expertise of hundreds of skilled auditors, these competitions foster a proactive bug hunting environment to fortify projects before their launch. Unlike traditional security assessments, Hats Audit Competitions operate on a time-based and results-driven model, ensuring that only successful auditors are rewarded for their contributions. This pay-for-results ethos not only allocates budgets more efficiently by paying exclusively for identified vulnerabilities but also retains funds if no issues are discovered. With a streamlined evaluation process, Hats prioritizes quality over quantity by rewarding the first submitter of a vulnerability, thus eliminating duplicate efforts and attracting top talent in web3 auditing. The process embodies Hats Finance's commitment to reducing fees, maintaining project control, and promoting high-quality security assessments, setting a new standard for decentralized security in the web3 space​​.

## Accumulated finance Overview

Omnichain modular liquid staking and restaking. Boosted staking yields and extra rewards for stakers.

## Competition Details


- Type: A public audit competition hosted by Accumulated finance
- Duration: 14 days
- Maximum Reward: $35,428.07
- Submissions: 100
- Total Payout: $16,407.1 distributed among 12 participants.

## Scope of Audit

# Project Overview
Accumulated Finance is an omnichain liquid staking protocol.

# Attack goals
We are launching ROSE liquid staking on Oasis Sapphire with on-chain stake delegation from Oasis Sapphire to Oasis Consensus Layer using Oasis Subcall library.

- Be able to take deposited assets (ROSE) from stROSE Minter
- Be able to receive more stROSE than expected from stROSE Minter
- Be able to receive more ROSE using built-in stROSE Minter withdrawal system, which is based on ERC-721 withdrawal requests
- Be able to disrupt the functionality of stROSE Minter that may lead to loss of user funds
- Find bugs in Oasis Subcall library and its methods, used in stROSE Minter, that may lead to loss of user funds

# Audit competition scope

```
|-- contracts
     |-- Minter.sol
     |-- minters
          |-- stROSEMinter.sol
```



# Deployments

Deployed contracts on Oasis Sapphire Testnet. You can interact with Accumulted Finance ROSE Liquid Staking with our frontend. Testing attacks on the deployed contracts is permissible before the end of the competition (if bugs are found out we'll redeploy).

## Frontend
https://testnet.accumulated.finance/stake/rosebeta

## Oasis Sapphire Testnet

- stROSEMinter: 0x3b3223ccf802e295202917330c59bd50f74d20ae
- stROSE (ERC-20): 0x9cd892c37258290bcdc59dc8e159785fb0045b18
- wstROSE (ERC-4626): 0x3be7a9e2526f6be015f3b2b13fe5fb9444ada20f

 ## Medium severity issues

- **Potential NFT Manipulation in requestWithdrawal Function due to _safeMint Usage**
The requestWithdrawal() function in the Mintersol contract allows users to request token withdrawals by transferring staking tokens to the contract. A new NFT, with an incremented withdrawal ID, is minted to the user via _safeMint(). This poses a security risk similar to a past incident where _safeMint() was exploited. The vulnerability occurs if the receiving smart contract deliberately rejects NFT reception, causing a transaction revert, and the attacker selectively mints desirable NFTs. The recommended solution is to replace _safeMint() with _mint() to eliminate the possibility of exploitation. Moreover, while the NFTs only serve as identifiers for deposit operations and lack uniqueness, the costs associated with attack attempts are significantly high due to the gas fees.
Link: [Issue #27](https://github.com/hats-finance/OLD-Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/27)


## Low severity issues

- **Native Token ClaimWithdrawal Function Lacks Claimed Status Check in Minter.sol**
In the minter.sol contract, the claimWithdrawal function for native tokens lacks a crucial check to ensure a withdrawal hasn't already been claimed, unlike its ERC20 counterpart. Although marking a withdrawal as claimed without this check doesn't immediately cause loss of funds, it results in inconsistent behavior. A code fix to include this verification step is recommended.
Link: [Issue #19](https://github.com/hats-finance/OLD-Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/19)

- **Reentrancy issue in collectWithdrawalFees due to CEI pattern violation**
In Minter.sol, the collectWithdrawalFees() function allows owners to withdraw fees but may be vulnerable to reentrancy attacks. This is due to a violation of the Checks-Effects-Interactions (CEI) pattern, where external calls should occur last. It’s recommended to update the pattern or add a nonReentrant modifier to secure the function.
Link: [Issue #26](https://github.com/hats-finance/OLD-Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/26)


- **AccumulatedFi contracts vulnerability with Solmate's SafeTransferLib affecting fund transfers**

  AccumulatedFi contracts use the `SafeTransferLib` from Solmate, which does not check for the existence of a token contract. This can result in false successes for fund transfers, leading to potential fund loss. It is recommended to use OpenZeppelin's SafeERC20 for proper code existence checks to avoid such risks.


  **Link**: [Issue #51](https://github.com/hats-finance/Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/51)


- **collectWithdrawalFees emits zero due to resetting totalWithdrawalFees before event**

  The `collectWithdrawalFees` function emits an event showing 0 fees collected because `totalWithdrawalFees` is reset to 0 before the event is emitted. This results in incorrect event data, rendering it unusable for frontend or indexing. It is recommended to save `totalWithdrawalFees` in a local variable before resetting and use this variable in the event.


  **Link**: [Issue #20](https://github.com/hats-finance/Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/20)


- **Add Minimum Deposit Limit to Prevent Spam in Minter Contract**

  The `deposit()` function in the `Minter.sol` contract lacks a check for a minimum deposit amount, potentially permitting spamming with very small token deposits. This could disrupt legitimate users trying to deposit ROSE tokens. Implementing a minimum deposit limit is recommended, aligning with existing minimum withdrawal checks to prevent abuse.


  **Link**: [Issue #10](https://github.com/hats-finance/Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/10)


- **Minimum Delegation Amount for ROSE Tokens Not Enforced in stROSEMinter.sol**

  The `delegate()` function in `stROSEMinter.sol` does not enforce a minimum delegation amount as required by OASIS, which is 100 ROSE tokens. This oversight allows users to delegate any amount, which could result in failed transactions if the required minimum is not met. It is recommended to add a validation to ensure delegations meet the 100 ROSE minimum.


  **Link**: [Issue #4](https://github.com/hats-finance/Accumulated-finance-0x75278bcc0fa7c9e3af98654bce195eaf3bb6a784/issues/4)



## Conclusion

Hats.finance offers a decentralized approach to web3 security with its audit competitions, which utilize broad auditor expertise to reinforce projects' security before they launch. These competitions emphasize quality by incentivizing only successful vulnerability discoveries, thereby optimizing budget utilization and engagement with top audit talent. In a recent competition hosted by Accumulated Finance, focusing on their ROSE liquid staking project, $16,407.1 was awarded to successful participants from a maximum of $35,428.07 based on identified vulnerabilities. The audit targeted critical components like the stROSE Minter contracts and highlighted essential areas for improvement in security governance, such as strengthening fund transfer checks, implementing a minimum deposit limit, and ensuring compliance with minimum delegation requirements for the Oasis platform. Mitigating identified low-severity issues, such as those associated with Solmate's SafeTransferLib, is crucial for preventing potential funds loss and maintaining robust security orchestration, aligning with Hats.finance's mission to enhance Web3 ecosystem resiliency through decentralized security solutions.

## Disclaimer


This report does not assert that the audited contracts are completely secure. Continuous review and comprehensive testing are advised before deploying critical smart contracts.


The Accumulated finance audit competition illustrates the collaborative effort in identifying and rectifying potential vulnerabilities, enhancing the overall security and functionality of the platform.


Hats.finance does not provide any guarantee or warranty regarding the security of this project. Smart contract software should be used at the sole risk and responsibility of users.
