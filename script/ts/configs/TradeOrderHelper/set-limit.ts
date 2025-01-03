import { Command } from "commander";
import { loadConfig, loadMarketConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { TradeOrderHelper__factory } from "../../../../typechain";
import { ethers } from "ethers";
import { findChainByName } from "../../entities/chains";

async function main(chainId: number) {
  const inputs = [
    { marketIndex: 0, positionSizeLimit: 750_000, tradeSizeLimit: 750_000 },
    { marketIndex: 1, positionSizeLimit: 750_000, tradeSizeLimit: 750_000 },
  ];

  const config = loadConfig(chainId);
  const marketConfig = loadMarketConfig(chainId);
  const deployer = await signers.deployer(chainId);
  console.log("Deployer:", await deployer.getAddress());
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const limitTradeHelper = TradeOrderHelper__factory.connect(config.helpers.tradeOrder!, deployer);

  console.log(`[configs/TradeOrderHelper] Set Limit By Market Index...`);
  console.table(
    inputs.map((i) => {
      return {
        marketIndex: i.marketIndex,
        market: marketConfig.markets[i.marketIndex].name!,
        positionSizeLimit: i.positionSizeLimit,
        tradeSizeLimit: i.tradeSizeLimit,
      };
    })
  );

  await ownerWrapper.authExec(
    limitTradeHelper.address,
    limitTradeHelper.interface.encodeFunctionData("setLimit", [
      inputs.map((input) => input.marketIndex),
      inputs.map((input) => ethers.utils.parseUnits(input.positionSizeLimit.toString(), 30)),
      inputs.map((input) => ethers.utils.parseUnits(input.tradeSizeLimit.toString(), 30)),
    ])
  );
}

const program = new Command();

// program.requiredOption("--chain-id <number>", "chain id", parseInt);
program.requiredOption("--chain <chain>", "chain alias");

const opts = program.parse(process.argv).opts();

const chain = findChainByName(opts.chain);
main(chain.id!)
  .then(() => {
    process.exit(0);
  })
  .catch((e) => {
    console.error(e);
    process.exit(1);
  });
