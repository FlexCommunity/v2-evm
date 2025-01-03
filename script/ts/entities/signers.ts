import { ethers } from "ethers";
import dotenv from "dotenv";
import chains from "./chains";
import hre from "hardhat";

dotenv.config();

export default {
  deployer: async (chainId: number): Promise<ethers.Signer> => {
    const hreSigners = await hre.ethers.getSigners();
    if (hreSigners.length > 0) return hreSigners[0];

    if (!process.env.MAINNET_PRIVATE_KEY) throw new Error("Missing ARBI_MAINNET_PRIVATE_KEY env var");
    return new ethers.Wallet(process.env.MAINNET_PRIVATE_KEY, chains[chainId].jsonRpcProvider);
  },
};
