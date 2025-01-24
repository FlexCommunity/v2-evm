import { ethers, tenderly, upgrades, getChainId, run, network } from "hardhat";
import { loadConfig } from "../../utils/config";
import signers from "../../entities/signers";
import ProxyAdminWrapper from "../../wrappers/ProxyAdminWrapper";
import { getImplementationAddress } from "@openzeppelin/upgrades-core";

async function main() {
  const chainId = Number(await getChainId());
  const config = loadConfig(chainId);
  const deployer = await signers.deployer(chainId);
  const proxyAdminWrapper = new ProxyAdminWrapper(chainId, deployer);

  const LiquidityHandler = await ethers.getContractFactory("LiquidityHandler", deployer);
  const liquidityHandler = config.handlers.liquidity!;
  console.log("liquidityHandler", liquidityHandler);

  console.log(`[upgrade/LiquidityHandler] Preparing to upgrade LiquidityHandler`);
  const newImplementation = await upgrades.prepareUpgrade(liquidityHandler, LiquidityHandler);
  console.log(`[upgrade/LiquidityHandler] Done`);

  console.log(`[upgrade/LiquidityHandler] New LiquidityHandler Implementation address: ${newImplementation}`);
  await proxyAdminWrapper.upgrade(liquidityHandler, newImplementation.toString());
  console.log(`[upgrade/LiquidityHandler] Upgraded!`);

  console.log(`[upgrade/LiquidityHandler] Verify contract on Tenderly at`, await getImplementationAddress(network.provider, config.handlers.liquidity!));
  await tenderly.verify({
    address: await getImplementationAddress(network.provider, config.handlers.liquidity!),
    name: "LiquidityHandler",
  });

  await run("verify:verify", {
    address: await getImplementationAddress(network.provider, config.handlers.liquidity!),
    constructorArguments: [],
  });

}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
