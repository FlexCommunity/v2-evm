import { loadConfig } from "../../utils/config";
import { RebalanceHLPHandler__factory } from "../../../../typechain";
import signers from "../../entities/signers";
import { passChainArg } from "../../utils/main-fn-wrappers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";

async function main(chainId: number) {

  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const executors = [
    await deployer.getAddress(),
  ]

  const rebalanceHandler = RebalanceHLPHandler__factory.connect(config.handlers.rebalanceHLP, deployer);

  for (const executor of executors) {
    if (await rebalanceHandler.whitelistExecutors(executor)) {
      console.log(`[configs/RebalanceHLPHandler] Executor ${executor} is already whitelisted`);
      continue;
    }

    console.log(`[configs/RebalanceHLPHandler] Set whitelist to address: ${executor}`);

    await ownerWrapper.authExec(
      rebalanceHandler.address,
      rebalanceHandler.interface.encodeFunctionData("setWhitelistExecutor", [executor, true])
    );

  }

}

passChainArg(main)


