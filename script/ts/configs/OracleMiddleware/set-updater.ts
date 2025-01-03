import { ethers } from "hardhat";
import { OracleMiddleware__factory } from "../../../../typechain";
import { getConfig } from "../../utils/config";

const config = getConfig();

const updaters = [
  "0x0000C5b439c9B902A21eF1F5365cbdF7e696A000",
  config.handlers.bot,
  "0xbbbe424b47c0EE77E0fb0Bb593617636Ee54D001",
  "0xbbb027210e4D34a71a735A66358b1E6b564AE002",
  "0xbbb8b1aA2F2b75C111dFBCe1e8e944c3673C7003",
  "0xbbbD2CA97D353820F6BB530556eD1786D6771004",
  "0xbbb5B311BB5CfA375BfD9C14EDc297d8AAe27006",
  "0xbbb805433305A837755BEA1681B134a4244c8007",
];


async function main() {
  const deployer = (await ethers.getSigners())[0];
  const oracle = OracleMiddleware__factory.connect(config.oracles.middleware, deployer);

  console.group(`[configs/OracleMiddleware]`);
  for(const updater of updaters) {
    console.log("Set Updater...", updater);
    const transaction = await oracle.setUpdater(updater, true);
    console.log("> OracleMiddleware Set Updater success!");
    await transaction.wait(2);
    console.log("Set Updater for Order Executor success! Tx:", transaction.hash);
  }
  console.groupEnd();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
