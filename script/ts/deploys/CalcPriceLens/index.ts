import { ethers, run, tenderly } from "hardhat";
import { getConfig, writeConfigFile } from "../../utils/config";

async function main() {
  const config = getConfig();
  const deployer = (await ethers.getSigners())[0];

  console.log(`Deploying CalcPriceLens Contract`);
  const Contract = await ethers.getContractFactory("CalcPriceLens", deployer);
  const contract = await Contract.deploy();
  await contract.deployed();
  console.log(`Deployed at: ${contract.address}`);

  config.oracles.calcPriceLens = contract.address;
  writeConfigFile(config);

  await run("verify:verify", {
    address: config.oracles.calcPriceLens,
    constructorArguments: [],
  });

  await tenderly.verify({
    address: config.oracles.calcPriceLens,
    name: "CalcPriceLens",
  });

}

main()
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
