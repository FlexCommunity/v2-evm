import { ethers, run, upgrades, network, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  const Contract = await ethers.getContractFactory("IntentHandler", deployer);

  const contract = await upgrades.deployProxy(Contract, [
    config.oracles.ecoPyth2,
    config.storages.config,
    config.helpers.tradeOrder,
    config.services.gas,
  ]);
  await contract.deployed();
  console.log(`Deploying IntentHandler Contract`);
  console.log(`Deployed at: ${contract.address}`);

  config.handlers.intent = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: await getImplementationAddress(network.provider, config.handlers.intent),
    constructorArguments: [],
  });

  await tenderly.verify({
    address: await getImplementationAddress(network.provider, config.handlers.intent),
    name: "IntentHandler",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
