import { ethers } from "ethers";
import { OracleMiddleware__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const assetConfigs = [
    {
      assetId: ethers.utils.formatBytes32String("ETH"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("BTC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
    {
      assetId: ethers.utils.formatBytes32String("USDC"),
      confidenceThreshold: 0,
      trustPriceAge: 60 * 5, // 5 minutes
      adapter: config.oracles.pythAdapter,
    },
  ];

  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.log("[configs/OracleMiddleware] Setting asset price configs...");
  await ownerWrapper.authExec(
    oracle.address,
    oracle.interface.encodeFunctionData("setAssetPriceConfigs", [
      assetConfigs.map((each) => each.assetId),
      assetConfigs.map((each) => each.confidenceThreshold),
      assetConfigs.map((each) => each.trustPriceAge),
      assetConfigs.map((each) => each.adapter),
    ])
  );
}

passChainArg(main);