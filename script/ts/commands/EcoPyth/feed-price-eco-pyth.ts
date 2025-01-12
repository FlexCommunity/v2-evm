import { EcoPyth__factory } from "../../../../typechain";
import { ecoPythPriceFeedIdsByIndex } from "../../constants/eco-pyth-index";
import * as readlineSync from "readline-sync";
import { loadConfig } from "../../utils/config";
import { getUpdatePriceData } from "../../utils/price";
import signers from "../../entities/signers";
import chains from "../../entities/chains";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const provider = chains[chainId].jsonRpcProvider;
  const deployer = await signers.deployer(chainId);

  const pyth = EcoPyth__factory.connect(config.oracles.ecoPyth2, deployer);

  const [readableTable, minPublishedTime, priceUpdateData, publishTimeDiffUpdateData, hashedVaas] =
    await getUpdatePriceData(ecoPythPriceFeedIdsByIndex, provider);
  console.table(readableTable);
  const confirm = readlineSync.question(`[cmds/EcoPyth] Confirm to update price feeds? (y/n): `);
  switch (confirm) {
    case "y":
      break;
    case "n":
      console.log("[cmds/EcoPyth] Feed Price cancelled!");
      return;
    default:
      console.log("[cmds/EcoPyth] Invalid input!");
      return;
  }

  console.log("[cmds/EcoPyth] Feed Price...");
  const tx = await (
    await pyth.updatePriceFeeds(priceUpdateData, publishTimeDiffUpdateData, minPublishedTime, hashedVaas)
  ).wait();
  console.log(`[cmds/EcoPyth] Done: ${tx.transactionHash}`);
  console.log("[cmds/EcoPyth] Feed Price success!");
  // console.log("[cmds/EcoPyth] Refreshing Asset Ids at HMX API...");
  // await hmxApi.refreshAssetIds();
  // console.log("[cmds/EcoPyth] Success!");
  // console.log("[cmds/EcoPyth] Refreshing Market Ids at HMX API...");
  // await hmxApi.refreshMarketIds();
  console.log("[cmds/EcoPyth] Success!");
}

passChainArg(main);