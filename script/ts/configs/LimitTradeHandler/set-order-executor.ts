import { ethers } from "hardhat";
import {
  LimitTradeHandler__factory,
} from "../../../../typechain";
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

  console.group("[config/LimitTradeHandler] Set");
  for(const orderExecutor of orderExecutors) {
    console.log(`> LimitTradeHandler: Set Order Executor ${orderExecutor}...`);
    const limitTradeHandler = LimitTradeHandler__factory.connect(config.handlers.limitTrade!, deployer);
    let transaction = await limitTradeHandler.setOrderExecutor(orderExecutor, true);
    await transaction.wait(2);
    console.log("> LimitTradeHandler: Set Order Executor success! Tx:", transaction.hash);
  }
  console.groupEnd();
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
