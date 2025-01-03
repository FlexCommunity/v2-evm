import { IntentHandler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { OwnerWrapper } from "../../wrappers/OwnerWrapper";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const ownerWrapper = new OwnerWrapper(chainId, deployer);

  const intentExecutors = [
    "0xbbbe424b47c0EE77E0fb0Bb593617636Ee54D001",
    "0xbbb027210e4D34a71a735A66358b1E6b564AE002",
    "0xbbb8b1aA2F2b75C111dFBCe1e8e944c3673C7003",
    "0xbbbD2CA97D353820F6BB530556eD1786D6771004",
    "0xbbb5B311BB5CfA375BfD9C14EDc297d8AAe27006",
    "0xbbb805433305A837755BEA1681B134a4244c8007",
  ];

  console.group(`[configs/IntentHandler]`);
  for(const intentExecutor of intentExecutors) {
    const isAllow = true;

    const intentHandler = IntentHandler__factory.connect(config.handlers.intent, deployer);
    console.log(`Set Intent Executor`, intentExecutor, isAllow);
    await ownerWrapper.authExec(
      intentHandler.address,
      intentHandler.interface.encodeFunctionData("setIntentExecutor", [intentExecutor, isAllow])
    );
    console.log("Finished");
  }
  console.groupEnd();

}

passChainArg(main)