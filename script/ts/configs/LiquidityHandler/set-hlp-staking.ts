import { getChainId } from "hardhat";
import { LiquidityHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { runMainAsAsync } from "../../utils/main-fn-wrappers";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);

  console.log("> LiquidityHandler: Set HLP Staking...");
  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, deployer);
  await (await handler.setHlpStaking(config.staking.hlp)).wait();
  console.log("> LiquidityHandler: Set HLP Staking success!");
}

runMainAsAsync(main)