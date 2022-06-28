const { expect } = require("chai");
const { assert } = require("chai");
const { ethers } = require("hardhat");

describe("ERC1155 contracts Tests", function () {
  let admin;
  let minter;
  let vault;
  let lister;
  let commerce;
  let newCollection;

  let deployer;
  let alice;
  let bob;
  let charlie;

  let marketFee = 200;
  before(async function () {
    [deployer, alice, bob, charlie] = await ethers.getSigners();
    const Admin = await ethers.getContractFactory("AdminConsole");
    admin = await Admin.deploy();
    await admin.deployed();
    // console.log(`Admin contract address is ${admin.address}`);

    const Vault = await ethers.getContractFactory("MyNFTStorage");
    vault = await Vault.deploy(admin.address);
    await vault.deployed();
    // console.log(`Vault contract address is ${vault.address}`);

    const Minter = await ethers.getContractFactory("Monion1155");
    minter = await Minter.deploy(vault.address, admin.address);
    await minter.deployed();
    // console.log(`Minter contract address is ${minter.address}`);

    const Lister = await ethers.getContractFactory("Listing");
    lister = await Lister.deploy(vault.address, minter.address);
    await lister.deployed();
    // console.log(`Lister contract address is ${lister.address}`);

    const Commerce = await ethers.getContractFactory("Commerce");
    commerce = await Commerce.deploy(vault.address, admin.address);
    await commerce.deployed();
    // console.log(`Commerce contract address is ${commerce.address}`);
  });
  it("should allow admin add all the member contracts", async function () {
    // let adminArr = [minter.address, vault.address, lister.address, commerce.address];
    // for(let i = 0; i < adminArr; i++){
    //   await admin.connect(deployer).addMember(adminArr[i]);
    //   console.log("Added: ", adminArr[i])
    // }
    await admin.connect(deployer).addMember(minter.address);
    await admin.connect(deployer).addMember(vault.address);
    await admin.connect(deployer).addMember(lister.address);
    await admin.connect(deployer).addMember(commerce.address);

    await admin.connect(deployer).setFeeAccount(deployer.address);
    await admin.connect(deployer).setFeePercent(marketFee);

    expect(await admin.connect(deployer).getFeeAccount()).to.equal(
      deployer.address
    );
    expect(await admin.connect(deployer).getFeePercent()).to.equal(200);
    expect(await admin.connect(deployer).isAdmin(minter.address)).to.equal(
      true
    );
    expect(await admin.connect(deployer).isAdmin(vault.address)).to.equal(true);
    expect(await admin.connect(deployer).isAdmin(lister.address)).to.equal(
      true
    );
    expect(await admin.connect(deployer).isAdmin(commerce.address)).to.equal(
      true
    );
  });
  it("should NOT allow a non-admin member to add users to add addresses to the admin address array", async function () {
    try {
      await admin.connect(alice).addMember(alice.address);
    } catch (error) {
      assert(
        error.message.includes("You do not have permission to add members")
      );
      return;
    }
    assert(false);
  });
  it("should allow a user mint NFTs from Monion's instance", async function () {
    expect(await lister.connect(alice).mintMonionNFT(4, 200))
      .to.emit(minter, "Minted")
      .withArgs(1, alice.address, 4);
  });
  it("should allow a user mint NFTs from user defined instance", async function () {
    const UserNFT = await ethers.getContractFactory("UserDefined1155", alice);
    newCollection = await UserNFT.deploy(vault.address);
    await newCollection.deployed();

    expect(await newCollection.connect(alice).mint(alice.address, 4, 200))
      .to.emit(newCollection, "Minted")
      .withArgs(1, alice.address, newCollection.address, 4);
  });
  it("should allow a user list monion minted NFTs", async function () {
    const tokenPrice = ethers.utils.parseEther("3");
    // const tx = await minter.balanceOf(alice.address, 1)
    // console.log(tx)
    await minter.connect(alice).setApprovalForAll(vault.address, true);
    await lister
      .connect(alice)
      .addMonionListingForSale(minter.address, 1, tokenPrice, 3);
    const tx = await vault
      .connect(alice)
      .getToken(minter.address, 1, alice.address);
    // console.log(tx);
    expect(tx.tokenPrice).to.equal(
      await vault.getTokenPrice(minter.address, 1, alice.address)
    );
    expect(tx.owner).to.equal(
      await vault.getTokenOwner(minter.address, 1, alice.address)
    );
    expect(tx.quantity).to.equal(
      await vault.getAvailableQty(minter.address, 1, alice.address)
    );
  });
  it("should allow a user list a userDefined NFT", async function () {
    //0xd8058efe0198ae9dd7d563e1b4938dcbc86a1f81

    const tokenPrice = ethers.utils.parseEther("4");
    await newCollection.connect(alice).setApprovalForAll(vault.address, true);
    await lister
      .connect(alice)
      .addMonionListingForSale(newCollection.address, 1, tokenPrice, 4);

    const tokenItem = await vault
      .connect(alice)
      .getToken(newCollection.address, 1, alice.address);
    // console.log(tx)
    expect(tokenItem.tokenPrice).to.equal(
      await vault.getTokenPrice(newCollection.address, 1, alice.address)
    );
    expect(tokenItem.owner).to.equal(
      await vault.getTokenOwner(newCollection.address, 1, alice.address)
    );
    expect(tokenItem.quantity).to.equal(
      await vault.getAvailableQty(newCollection.address, 1, alice.address)
    );
  });
  it("should allow users to send offers", async function () {
    let price = await vault.getTokenPrice(minter.address, 1, alice.address);
    console.log(price);
    // price = price*2.5;
    // console.log(price)
    const tokenPrice1 = ethers.utils.parseEther("8");
    await commerce
      .connect(bob)
      .sendBuyOffer(minter.address, 1, alice.address, 2, {
        value: tokenPrice1,
      });

    const tokenPrice2 = ethers.utils.parseEther("11");
    await commerce
      .connect(charlie)
      .sendBuyOffer(minter.address, 1, alice.address, 2, {
        value: tokenPrice2,
      });
  });
  it("should allow the minter to view an offer", async function () {
    const offers = await commerce
      .connect(alice)
      .viewOffers(minter.address, 1, alice.address);
    expect(offers[0].qty).to.equal(2);
    expect(offers[0].sender).to.equal(bob.address);
    offer = offers[0].qty;

    expect(offers[1].qty).to.equal(2);
    expect(offers[1].sender).to.equal(charlie.address);
    // console.log(offers[0]);
    // console.log(offers[1]);
  });
  it("should allow the minter accept an offer", async function () {
    const balBefore = await commerce.connect(alice).getDeposit();
    // const offers = await commerce
    //   .connect(deployer)
    //   .viewOffers(minter.address, 1, alice.address);
    // console.log("Before :",offers);
    await commerce.connect(alice).acceptOffer(minter.address, 1, 0);

    // const offers1 = await commerce
    //   .connect(deployer)
    //   .viewOffers(minter.address, 1, alice.address);
    // console.log("After: ",offers1);

    const tx = await vault
      .connect(bob)
      .getToken(minter.address, 1, bob.address);
    // console.log(tx);
    expect(tx.tokenPrice).to.equal(
      await vault.getTokenPrice(minter.address, 1, bob.address)
    );
    expect(tx.owner).to.equal(
      await vault.getTokenOwner(minter.address, 1, bob.address)
    );
    expect(tx.quantity).to.equal(
      await vault.getAvailableQty(minter.address, 1, bob.address)
    );

    const balAfter = await commerce.connect(alice).getDeposit();
    console.log(
      `Alice's balance before the offer was ${balBefore}, and after the offer is ${balAfter}`
    );
    const diff = balAfter - balBefore;
    expect(diff).to.be.greaterThan(0);
  });
  it("should ERROR out when a non user tries to withdraw an offer", async function () {
    try {
      await commerce
        .connect(alice)
        .withdrawOffer(minter.address, 1, alice.address);
    } catch (error) {
      // console.log(error.message)
      assert(error.message.includes("You do not have an existing offer!"));
      return;
    }
    assert(false);
  });
  xit("should check whether an account has an Offer", async function () {
    // const offers1 = await commerce
    //   .connect(deployer)
    //   .viewOffers(minter.address, 1, alice.address);
    // console.log("Existing Offers: ", offers1);
    // expect(offers1[0].sender).to.equal(charlie.address);
    const hasOffer = await commerce.offerExists(
      minter.address,
      1,
      alice.address,
      charlie.address
    );
    // console.log(hasOffer);
    console.log(
      `Does Charlie have an offer?: ${hasOffer.answer} with index ${hasOffer.index}`
    );
    // console.log(`Does Charlie have an offer?: ${hasOffer.answer}`);
  });
  it("should allow user to withdraw an unused offer", async function () {
    // const offers = await commerce
    //   .connect(deployer)
    //   .viewOffers(minter.address, 1, alice.address);
    // expect(offers.length).to.equal(1);
    await commerce
      .connect(charlie)
      .withdrawOffer(minter.address, 1, alice.address);
    const offers1 = await commerce
      .connect(deployer)
      .viewOffers(minter.address, 1, alice.address);

    expect(offers1.length).to.equal(0);
  });
  it("should allow the owner withdraw NFTs", async function () {
    expect(
      await vault.connect(bob).getAvailableQty(minter.address, 1, bob.address)
    ).to.equal(2);
    await commerce.connect(bob).withdrawNFTs(minter.address, 1, 1);
    expect(
      await vault.connect(bob).getAvailableQty(minter.address, 1, bob.address)
    ).to.equal(1);
    expect(await minter.balanceOf(bob.address, 1)).to.equal(1);
  });
  it("should allow creator's earn secondary revenue from royalties", async function () {
    const tokenPrice2 = ethers.utils.parseEther("2");
    await lister.connect(bob).updatePrice(minter.address, 1, tokenPrice2);
    const tx = await vault
      .connect(bob)
      .getToken(minter.address, 1, bob.address);
    expect(tx.tokenPrice).to.equal(tokenPrice2);
    const tokenPrice3 = ethers.utils.parseEther("3");
    await commerce
      .connect(charlie)
      .sendBuyOffer(minter.address, 1, bob.address, 1, { value: tokenPrice3 });

    const balBefore = await commerce.connect(alice).getDeposit();
    await commerce.connect(bob).acceptOffer(minter.address, 1, 0);
    const balAfter = await commerce.connect(alice).getDeposit();
    console.log(
      `Alice's balance before the offer was ${balBefore}, and after the offer is ${balAfter}`
    );
    const diff = balAfter - balBefore;
    expect(diff).to.be.greaterThan(0);
  });
});
