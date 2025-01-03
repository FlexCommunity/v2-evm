import { ethers, run, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

const BigNumber = ethers.BigNumber;
const config = getConfig();

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`[deploys/PositionReader] Deploying PositionReader Contract`);
  const Contract = await ethers.getContractFactory("PositionReader", deployer);
  const contract = await Contract.deploy(
    config.storages.config!,
    config.storages.perp!,
    config.oracles.middleware!,
    config.calculator!,
  );
  await contract.deployed();
  console.log(`[deploys/PositionReader] Deployed at: ${contract.address}`);

  config.reader.position = contract.address;
  writeConfigFile(config);

  console.log(`[deploys/PositionReader] Verify contract on Etherscan`);
  
  await run("verify:verify", {
    address: config.reader.position,
    constructorArguments: [config.storages.config, config.storages.perp, config.oracles.middleware, config.calculator],
  });

  await tenderly.verify({
    address: config.reader.position,
    name: "PositionReader",
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
