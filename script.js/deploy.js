const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying GasOptimizer contract...");

  // Get the ContractFactory and Signers here
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await deployer.getBalance()).toString());

  // Deploy the contract
  const GasOptimizer = await ethers.getContractFactory("GasOptimizer");
  const gasOptimizer = await GasOptimizer.deploy();

  await gasOptimizer.deployed();

  console.log("GasOptimizer contract deployed to:", gasOptimizer.address);
  console.log("Transaction hash:", gasOptimizer.deployTransaction.hash);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
