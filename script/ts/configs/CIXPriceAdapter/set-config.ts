import { Command } from "commander";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { CIXPriceAdapter__factory } from "../../../../typechain";
import { ethers } from "ethers";
import { compareAddress } from "../../utils/address";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);
  const cixPriceAdapter = CIXPriceAdapter__factory.connect(config.oracles.priceAdapters.dix, deployer);

  const cE8 = ethers.utils.parseUnits("47.46426", 8);
  const assetIds = [
    ethers.utils.formatBytes32String("EUR"),
    ethers.utils.formatBytes32String("JPY"),
    ethers.utils.formatBytes32String("GBP"),
    ethers.utils.formatBytes32String("CAD"),
    ethers.utils.formatBytes32String("SEK"),
    ethers.utils.formatBytes32String("CHF"),
  ];
  const weightsE8 = [
    ethers.utils.parseUnits("0.560", 8),
    ethers.utils.parseUnits("0.140", 8),
    ethers.utils.parseUnits("0.120", 8),
    ethers.utils.parseUnits("0.100", 8),
    ethers.utils.parseUnits("0.040", 8),
    ethers.utils.parseUnits("0.040", 8),
  ];

  const usdQuoteds = [
    true, // EURUSD
    false, // USDJPY
    true, // GBPUSD
    false, // USDCAD
    false, // USDSEK
    false, // USDCHF
  ];

  console.log(`[configs/CIXPriceAdapter] Set Config...`);
  await ownerWrapper.authExec(
    cixPriceAdapter.address,
    cixPriceAdapter.interface.encodeFunctionData("setConfig", [cE8, assetIds, weightsE8, usdQuoteds])
  );
}

passChainArg(main);