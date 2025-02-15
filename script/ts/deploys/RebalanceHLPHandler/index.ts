import { ethers, tenderly, upgrades, network } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";
import { runMainAsAsync } from "../../utils/main-fn-wrappers";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("RebalanceHLPHandler", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    config.services.rebalanceHLP!,
    config.oracles.ecoPyth2!,
  ]);
  await contract.deployed();

  console.log(`Deploying RebalanceHLPHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.rebalanceHLP = contract.address;
  writeConfigFile(config);

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "RebalanceHLPHandler",
  });
}

runMainAsAsync(main)
