import { ethers } from "ethers";
import { ConfigStorage__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import { Command } from "commander";
import signers from "../../entities/signers";
import SafeWrapper from "../../wrappers/SafeWrapper";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const configStorage = ConfigStorage__factory.connect(config.storages.config, deployer);

  const inputs = [
    {
      tokenAddress: config.tokens.usdc,
      config: {
        targetWeight: ethers.utils.parseEther("0.05"), // 5%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: true,
      },
    },
    {
      tokenAddress: config.tokens.usdt,
      config: {
        targetWeight: ethers.utils.parseEther("0"), // 0%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: false,
      },
    },
    {
      tokenAddress: config.tokens.dai,
      config: {
        targetWeight: ethers.utils.parseEther("0"), // 0%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: false,
      },
    },
    {
      tokenAddress: config.tokens.weth,
      config: {
        targetWeight: ethers.utils.parseEther("0"), // 0%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: false,
      },
    },
    {
      tokenAddress: config.tokens.wbtc,
      config: {
        targetWeight: ethers.utils.parseEther("0"), // 0%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: false,
      },
    },
    {
      tokenAddress: config.tokens.sglp,
      config: {
        targetWeight: ethers.utils.parseEther("0.95"), // 95%
        bufferLiquidity: 0,
        maxWeightDiff: ethers.utils.parseEther("1000"), // 100000 % (Don't check max weight diff at launch)
        accepted: false,
      },
    },
  ];

  console.log("[configs/ConfigStorage] AddOrUpdateAcceptedToken...");

  await (
    await configStorage.addOrUpdateAcceptedToken(
      inputs.map((each) => each.tokenAddress),
      inputs.map((each) => each.config)
    )
  ).wait();
}

const prog = new Command();

prog.requiredOption("--chain-id <number>", "chain id", parseInt);

prog.parse(process.argv);

const opts = prog.opts();

main(opts.chainId)
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
