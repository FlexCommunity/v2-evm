import { ethers, tenderly, upgrades, network, run } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();
const minHLPValueLossBPS = 50; // 0.5%

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("RebalanceHLPService", deployer);
  const contract = await upgrades.deployProxy(Contract, [
    ethers.constants.AddressZero,// config.tokens.sglp,
    ethers.constants.AddressZero, // config.vendors.gmx.rewardRouterV2,
    ethers.constants.AddressZero, //config.vendors.gmx.glpManager,
    config.storages.vault!,
    config.storages.config!,
    config.calculator!,
    config.extension.switchCollateralRouter!,
    minHLPValueLossBPS!,
  ]);

  await contract.deployed();
  console.log(`Deploying RebalanceHLPService Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.services.rebalanceHLP = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: await getImplementationAddress(network.provider, config.tokens.flp),
    constructorArguments: [],
  });

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, contract.address),
    name: "RebalanceHLPService",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
