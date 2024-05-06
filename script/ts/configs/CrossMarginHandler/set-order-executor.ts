import { ethers } from "hardhat";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const orderExecutor = "0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0";

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log("> CrossMarginHandler: Set Order Executor...");
  const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
  await (await crossMarginHandler.setOrderExecutor(orderExecutor, true)).wait();
  console.log("> CrossMarginHandler: Set Order Executor success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
