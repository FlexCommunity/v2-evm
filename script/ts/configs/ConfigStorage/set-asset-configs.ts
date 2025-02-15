import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      assetId: ethers.utils.formatBytes32String("USDC"),
      config: {
        assetId: ethers.utils.formatBytes32String("USDC"),
        tokenAddress: config.tokens.usdc!,
        decimals: 6,
        isStableCoin: true,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("ETH"),
      config: {
        assetId: ethers.utils.formatBytes32String("ETH"),
        tokenAddress: config.tokens.weth!,
        decimals: 18,
        isStableCoin: false,
      },
    },
    {
      assetId: ethers.utils.formatBytes32String("BTC"),
      config: {
        assetId: ethers.utils.formatBytes32String("BTC"),
        tokenAddress: config.tokens.wbtc!,
        decimals: 8,
        isStableCoin: false,
      },
    },
  ];

  console.log("[configs/ConfigStorage] Set Asset Configs...");
  await ownerWrapper.authExec(
    configStorage.address,
    configStorage.interface.encodeFunctionData("setAssetConfigs", [
      inputs.map((each) => each.assetId),
      inputs.map((each) => each.config),
    ])
  );
  console.log("[configs/ConfigStorage] Finished");
  console.log("[configs/ConfigStorage] Set Asset Configs success!");
}

passChainArg(main);