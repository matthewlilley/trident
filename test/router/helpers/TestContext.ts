import { ContractFactory } from "@ethersproject/contracts";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BentoBoxV1, MasterDeployer, Router } from "../../../types";
import { ethers } from "hardhat";
import { getBigNumber } from "@sushiswap/tines";

export class TestContext {
  public Signer!: SignerWithAddress;
  public FeeTo!: SignerWithAddress;

  public MasterDeployer!: MasterDeployer;
  public Bento!: BentoBoxV1;
  public Router!: Router;

  public Erc20Factory!: ContractFactory;

  public async init() {
    [this.Signer, this.FeeTo] = await ethers.getSigners();

    this.Erc20Factory = await ethers.getContractFactory("ERC20Mock");
    const weth = await this.Erc20Factory.deploy("WETH", "WETH", getBigNumber(Math.pow(2, 110)));
    await weth.deployed();

    this.Bento = (await (await ethers.getContractFactory("BentoBoxV1")).deploy(weth.address)) as BentoBoxV1;
    await this.Bento.deployed();

    this.MasterDeployer = (await (
      await ethers.getContractFactory("MasterDeployer")
    ).deploy(17, this.FeeTo.address, this.Bento.address)) as MasterDeployer;
    await this.MasterDeployer.deployed();

    this.Router = (await (
      await ethers.getContractFactory("Router")
    ).deploy(this.Bento.address, this.MasterDeployer.address, weth.address)) as Router;
    await this.Router.deployed();

    await this.Bento.whitelistMasterContract(this.Router.address, true);

    await this.Bento.setMasterContractApproval(
      this.Signer.address,
      this.Router.address,
      true,
      0,
      "0x0000000000000000000000000000000000000000000000000000000000000000",
      "0x0000000000000000000000000000000000000000000000000000000000000000"
    );
  }
}
