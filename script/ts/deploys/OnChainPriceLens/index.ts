import { ethers, run, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const contract = await ethers.deployContract("OnChainPriceLens", [], deployer);

  await contract.deployed();
  console.log(`[deploys/OnChainPriceLens] Deploying OnChainPriceLens Contract`);
  console.log(`[deploys/OnChainPriceLens] Deployed at: ${contract.address}`);

  config.oracles.onChainPriceLens = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: config.oracles.onChainPriceLens,
    constructorArguments: [],
  });

  await tenderly.verify({
    address: config.oracles.onChainPriceLens,
    name: "OnChainPriceLens",
  });
  
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
