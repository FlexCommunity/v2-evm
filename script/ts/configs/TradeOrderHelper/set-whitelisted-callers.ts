import { TradeOrderHelper__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const tradeOrderHelper = TradeOrderHelper__factory.connect(config.helpers.tradeOrder, deployer);
  console.log(`[configs/TradeOrderHelper] Set Whitelisted Callers`);
  await ownerWrapper.authExec(
    tradeOrderHelper.address,
    tradeOrderHelper.interface.encodeFunctionData("setWhitelistedCaller", [config.handlers.intent])
  );
  console.log("[configs/TradeOrderHelper] Finished");
}

passChainArg(main);