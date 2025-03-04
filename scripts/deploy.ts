import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log(`Deploying contracts with the account: ${deployer.address}`);

  const name = "stZETA";
  const symbol = "stZETA";
  const TokenA = await ethers.getContractFactory("stZETA");
  const stTokenDeployed = await TokenA.deploy(name, symbol, 18);

  const stTokenAddress = await stTokenDeployed.getAddress();
  console.log(`stZETA deployed at: ${stTokenAddress}`);
  const gasLimit = 5000000; // 5M gas

  const tokenB = await ethers.getContractFactory("wstZETA");
  const wstTokenDeployed = await tokenB.deploy(stTokenAddress, 604800, { gasLimit });

  const wstAddress = await wstTokenDeployed.getAddress();
  console.log(`wstZETA deployed at: ${wstAddress}`);

  const tokenC = await ethers.getContractFactory("stZETAMinter");
  const minterDeployed = await tokenC.deploy(stTokenAddress, { gasLimit });

  const minterAddress = await minterDeployed.getAddress();
  console.log(`stZETAMinter deployed at: ${minterAddress}`);

  const stZETA = await ethers.getContractAt("stZETA", stTokenAddress);

  console.log(`Transferring ownership to: ${minterAddress}...`);

  // Вызываем функцию смены владельца

  const tx = await stZETA.transferOwnership(minterAddress, {gasLimit});
  await tx.wait();

  console.log("✅ Ownership transferred successfully!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
