import { ethers } from "hardhat";
import { CrossMarginHandler__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const orderExecutors = [
  "0xbbbe424b47c0EE77E0fb0Bb593617636Ee54D001",
  "0xbbb027210e4D34a71a735A66358b1E6b564AE002",
  "0xbbb8b1aA2F2b75C111dFBCe1e8e944c3673C7003",
  "0xbbbD2CA97D353820F6BB530556eD1786D6771004",
  "0xbbb5B311BB5CfA375BfD9C14EDc297d8AAe27006",
  "0xbbb805433305A837755BEA1681B134a4244c8007",
];

async function main() {
  const deployer = (await ethers.getSigners())[0];

  console.group("[configs/CrossMarginHandler]");
  for (const orderExecutor of orderExecutors) {
    console.log("Set Order Executor...", orderExecutor);
    const crossMarginHandler = CrossMarginHandler__factory.connect(config.handlers.crossMargin, deployer);
    let transaction = await crossMarginHandler.setOrderExecutor(orderExecutor, true);
    await transaction.wait(2);
    console.log("Set Order Executor success! Tx: ", transaction.hash);
  }
  console.groupEnd();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
