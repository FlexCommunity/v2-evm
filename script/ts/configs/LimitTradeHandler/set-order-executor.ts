import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { ethers } from "hardhat";
import { EvmPriceServiceConnection } from "@pythnetwork/pyth-evm-js";
import {
  IPyth__factory,
  LimitTradeHandler__factory,
  MockPyth__factory,
  PythAdapter__factory,
} from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();
const BigNumber = ethers.BigNumber;
const parseUnits = ethers.utils.parseUnits;

const orderExecutor = "0xddfb5a5D0eF7311E1D706912C38C809Ac1e469d0";

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.log(`> LimitTradeHandler: Set Order Executor ${orderExecutor}...`);
  const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade, deployer);
  await (await limitTradeHandler.setOrderExecutor(orderExecutor, true)).wait();
  console.log("> LimitTradeHandler: Set Order Executor success!");
}
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
