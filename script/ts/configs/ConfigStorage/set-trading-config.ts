import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { passChainArg } from "../../utils/main-fn-wrappers";

const tradingConfig = {
  fundingInterval: 1, // second
  devFeeRateBPS: 1000, // 10%
  minProfitDuration: 15, // second
  maxPosition: 10, // 10 positions per sub-account max
};

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  console.log("[ConfigStorage] Set Trading Config...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setTradingConfig", [tradingConfig])
  );
}

passChainArg(main);