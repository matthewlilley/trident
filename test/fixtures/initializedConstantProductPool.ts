import { ethers, deployments } from "hardhat";
import { BentoBoxV1, ConstantProductPoolFactory, ConstantProductPool__factory, ERC20Mock__factory, MasterDeployer } from "../../types";

export const initializedConstantProductPool = deployments.createFixture(
  async (
    {
      deployments,
      ethers: {
        getNamedSigners,
        constants: { MaxUint256 },
      },
    },
    options
  ) => {
    await deployments.fixture(["ConstantProductPoolFactory"]); // ensure you start from a fresh deployments
    const { alice } = await getNamedSigners();

    const ERC20 = await ethers.getContractFactory<ERC20Mock__factory>("ERC20Mock");

    const token0 = await ERC20.connect(alice).deploy("Token 0", "TOKEN0", MaxUint256);
    await token0.deployed();

    const token1 = await ERC20.connect(alice).deploy("Token 1", "TOKEN1", MaxUint256);
    await token1.deployed();

    const masterDeployer = await ethers.getContract<MasterDeployer>("MasterDeployer");

    const constantProductPoolFactory = await ethers.getContract<ConstantProductPoolFactory>("ConstantProductPoolFactory");

    const deployData = ethers.utils.defaultAbiCoder.encode(
      ["address", "address", "uint256", "bool"],
      [token0.address, token1.address, 0, false]
    );

    const contractReceipt = await masterDeployer.deployPool(constantProductPoolFactory.address, deployData).then((tx) => tx.wait());

    const bento = await ethers.getContract<BentoBoxV1>("BentoBoxV1");

    await bento.whitelistMasterContract("0x0000000000000000000000000000000000000001", true);

    await token0
      .connect(alice)
      .approve(bento.address, MaxUint256)
      .then((tx) => tx.wait());

    await token1
      .connect(alice)
      .approve(bento.address, MaxUint256)
      .then((tx) => tx.wait());

    await bento
      .connect(alice)
      .setMasterContractApproval(
        alice.address,
        "0x0000000000000000000000000000000000000001",
        true,
        "0",
        "0x0000000000000000000000000000000000000000000000000000000000000000",
        "0x0000000000000000000000000000000000000000000000000000000000000000"
      )
      .then((tx) => tx.wait());

    await bento
      .connect(alice)
      .deposit(token0.address, alice.address, alice.address, "1000000000000000000", 0)
      .then((tx) => tx.wait());

    await bento
      .connect(alice)
      .deposit(token1.address, alice.address, alice.address, "1000000000000000000", 0)
      .then((tx) => tx.wait());

    await bento
      .connect(alice)
      .transfer(token0.address, alice.address, contractReceipt.events?.[0].args?.pool, "1000000000000000000")
      .then((tx) => tx.wait());

    await bento
      .connect(alice)
      .transfer(token1.address, alice.address, contractReceipt.events?.[0].args?.pool, "1000000000000000000")
      .then((tx) => tx.wait());

    const Pool = await ethers.getContractFactory<ConstantProductPool__factory>("ConstantProductPool");

    const pool = Pool.attach(contractReceipt.events?.[0].args?.pool);

    await pool
      .connect(alice)
      .mint(ethers.utils.defaultAbiCoder.encode(["address"], [alice.address]))
      .then((tx) => tx.wait());

    return pool;
  }
);
