import { task } from "hardhat/config";
import { constants } from "ethers";
import { ERC20Mock } from "../types";

const { MaxUint256 } = constants;

task("erc20-approve", "ERC20 approve")
  .addParam("token", "Token")
  .addParam("spender", "Spender")
  .setAction(async function ({ token, spender }, { ethers }, runSuper) {
    const dev = await ethers.getNamedSigner("dev");
    const erc20 = await ethers.getContractAt<ERC20Mock>("ERC20Mock", token);
    return erc20.connect(dev).approve(spender, MaxUint256);
  });
