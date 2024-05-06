import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const updater = "0xf0d00E8435E71df33bdA19951B433B509A315aee";

async function main() {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("> OracleMiddleware Set Updater...");
  await (await oracle.setUpdater(updater, true)).wait();
  console.log("> OracleMiddleware Set Updater success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
