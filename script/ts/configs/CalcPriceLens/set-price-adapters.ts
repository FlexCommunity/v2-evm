import { ethers } from "ethers";
import { CalcPriceLens, CalcPriceLens__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { Command } from "commander";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { compareAddress } from "../../utils/address";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const priceAdapters = [
    {
      priceId: ethers.utils.formatBytes32String("DIX"),
      adapter: config.oracles.priceAdapters.dix,
    },
  ];

  const deployer = await signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const lens = CalcPriceLens__factory.connect(config.oracles.calcPriceLens, deployer);
  const owner = await lens.owner();

  console.log("[configs/CalcPriceLens] Setting price adapters...");
  if (compareAddress(owner, config.safe)) {
    const tx = await safeWrapper.proposeTransaction(
      lens.address,
      0,
      lens.interface.encodeFunctionData("setPriceAdapters", [
        priceAdapters.map((each) => each.priceId),
        priceAdapters.map((each) => each.adapter),
      ])
    );
    console.log(`[configs/CalcPriceLens] Tx: ${tx}`);
  } else {
    const tx = await lens.setPriceAdapters(
      priceAdapters.map((each) => each.priceId),
      priceAdapters.map((each) => each.adapter)
    );
    console.log(`[configs/CalcPriceLens] Tx: ${tx.hash}`);
  }

  console.log("[configs/CalcPriceLens] Finished");
}

passChainArg(main);