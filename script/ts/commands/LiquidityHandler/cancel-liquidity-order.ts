import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import { LiquidityHandler__factory, ERC20__factory } from "../../../../typechain";
import { passChainArg } from "../../utils/main-fn-wrappers";

async function main(chainId: number) {
  const config = loadConfig(chainId);
  const signer = await signers.deployer(chainId);

  const handler = LiquidityHandler__factory.connect(config.handlers.liquidity, signer);
  const tx = await handler.cancelLiquidityOrder(
    0,
    {
      gasLimit: 40_000_000,
    }
  );
  console.log(`[LiquidityHandler] Tx: ${tx.hash}`);
  await tx.wait(1);
  console.log("[LiquidityHandler] Finished");
}

passChainArg(main);