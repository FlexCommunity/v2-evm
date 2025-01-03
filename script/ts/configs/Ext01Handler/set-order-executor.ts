import { Ext01Handler__factory } from "../../../../typechain";
import { loadConfig } from "../../utils/config";
import SafeWrapper from "../../wrappers/SafeWrapper";
import { Command } from "commander";
import signers from "../../entities/signers";
import { compareAddress } from "../../utils/address";
import { ethers } from "ethers";
import { findChainByName } from "../../entities/chains";
import { passChainArg } from "../../utils/main-fn-wrappers";

// OrderType 1 = Create switch collateral order
const SWITCH_COLLATERAL_ORDER_TYPE = 1;

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const safeWrapper = new SafeWrapper(chainId, config.safe, deployer);
  const ext01Handler = Ext01Handler__factory.connect(config.handlers.ext01, deployer);

  const orderExecutors = [
    "0xbbbe424b47c0EE77E0fb0Bb593617636Ee54D001",
    "0xbbb027210e4D34a71a735A66358b1E6b564AE002",
    "0xbbb8b1aA2F2b75C111dFBCe1e8e944c3673C7003",
    "0xbbbD2CA97D353820F6BB530556eD1786D6771004",
    "0xbbb5B311BB5CfA375BfD9C14EDc297d8AAe27006",
    "0xbbb805433305A837755BEA1681B134a4244c8007",
  ];
  const isAllow = true;

  console.group("[config/Ext01Handler]");
  for (const orderExecutor of orderExecutors) {
    console.log("Ext01Handler setOrderExecutor...", orderExecutor);
    const owner = await ext01Handler.owner();
    if (compareAddress(owner, config.safe)) {
      const tx = await safeWrapper.proposeTransaction(
        ext01Handler.address,
        0,
        ext01Handler.interface.encodeFunctionData("setOrderExecutor", [orderExecutor, isAllow])
      );
      console.log(`Proposed ${tx} to setOrderExecutor`);
    } else {
      const tx = await ext01Handler.setOrderExecutor(orderExecutor, isAllow);
      console.log(`setOrderExecutor Done at ${tx.hash}`);
      await tx.wait();
    }
  }

  console.groupEnd();

}

passChainArg(main)