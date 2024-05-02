import { ethers } from "hardhat";
import { expect } from "chai";

describe("Migration Contract Tests", function () {
    let oldWeirdo: any;
    let newWeirdo: any;
    let migration: any;
    let deployer: any;
    let weirdo1: any;
    let weirdo2: any;
    let weirdo3: any;
    let weirdo4: any;
    let weirdo5: any;
    let weirdo6: any;
    let weirdo7: any;
    let treasury: any;
    let oldWeirdoAddress: any;
    let newWeirdoAddress: any;
    let migrationAddress: any;

    beforeEach(async function () {
        // Get signers
        [deployer, weirdo1, weirdo2, weirdo3, weirdo4, weirdo5, weirdo6, weirdo7, treasury] = await ethers.getSigners();

        // Deploy the old Weirdo token
        const Token = await ethers.getContractFactory("Token", deployer);
        oldWeirdo = await Token.deploy(1000000);

        // Deploy the new Weirdo token
        newWeirdo = await Token.deploy(1000000000);

        // Deploy Migration contract
        const Migration = await ethers.getContractFactory("Migration", deployer);
        oldWeirdoAddress = await oldWeirdo.getAddress();
        newWeirdoAddress = await newWeirdo.getAddress();
        migration = await Migration.deploy(
            oldWeirdoAddress,
            newWeirdoAddress,
            1000,
            42,
            30,
            20,
            treasury,
            ethers.ZeroAddress);

        // distribute weirdo tokens
        await oldWeirdo.transfer(weirdo1, 20000);
        await oldWeirdo.transfer(weirdo2, 50000);
        await oldWeirdo.transfer(weirdo3, 25000);
        await oldWeirdo.transfer(weirdo4, 69);
        await oldWeirdo.transfer(weirdo5, 100000);
        await oldWeirdo.transfer(weirdo6, 120000);
        const remainingTokens = await oldWeirdo.balanceOf(deployer);
        await oldWeirdo.transfer(weirdo7, remainingTokens);

        // load migration address
        migrationAddress = await migration.getAddress();

        // fund the migration contract with new weirdo
        await newWeirdo.transfer(migrationAddress, 1000000000);

    });

    it("all getters should work properly", async function () {
        expect(await migration.getOldWeirdo()).to.equal(oldWeirdoAddress);
        expect(await migration.getNewWeirdo()).to.equal(newWeirdoAddress);
        expect(await migration.isMigrateCapReached()).to.equal(false);
        expect(await migration.getTreasury()).to.equal(treasury);
        expect(await migration.getUniV2Router()).to.equal(ethers.ZeroAddress);
        expect(await migration.getInflation()).to.equal(1000);
        expect(await migration.getTotalMigrated()).to.equal(0);
        expect(await migration.getMigrants()).to.equal(0);
        const now: any = (await ethers.provider.getBlock('latest'))?.timestamp;
        const thirtyDaysInSeconds = 30 * 24 * 60 * 60;
        const expectedTimeCap = now + thirtyDaysInSeconds;
        const marginOfError = 600;  // 10 minutes in seconds
        const actualTimeCap = await migration.getTimeCap();
        expect(actualTimeCap).to.be.closeTo(expectedTimeCap, marginOfError);
        expect(await migration.getMigrateCap()).to.equal(200000);
        expect(await migration.getTaxRate()).to.equal(42);
        expect(await migration.isMigrationOpened()).to.equal(true);
    });

    it("test basic migration", async function () {
        // weirdo1 gives allowance to the migration contract
        await oldWeirdo.connect(weirdo1).approve(migrationAddress, 20000);
        await migration.connect(weirdo1).migrate();
        expect(await oldWeirdo.balanceOf(weirdo1)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo1)).to.equal(20000000);
        expect(await oldWeirdo.balanceOf(migrationAddress)).to.equal(20000);
        expect(await migration.isMigrateCapReached()).to.equal(false);
        expect(await migration.getTotalMigrated()).to.equal(20000);
        expect(await migration.getMigrants()).to.equal(1);
        expect(await migration.isMigrationOpened()).to.equal(true);
    });
    it("test migration passing the cap", async function () {
        // weirdo1 gives allowance to the migration contract
        await oldWeirdo.connect(weirdo1).approve(migrationAddress, 1000000);
        await migration.connect(weirdo1).migrate();
        expect(await migration.isMigrateCapReached()).to.equal(false);
        await oldWeirdo.connect(weirdo2).approve(migrationAddress, 1000000);
        await migration.connect(weirdo2).migrate();
        expect(await migration.isMigrateCapReached()).to.equal(false);
        await oldWeirdo.connect(weirdo3).approve(migrationAddress, 1000000);
        await migration.connect(weirdo3).migrate();
        expect(await migration.isMigrateCapReached()).to.equal(false);
        await oldWeirdo.connect(weirdo4).approve(migrationAddress, 1000000);
        await migration.connect(weirdo4).migrate();
        expect(await migration.isMigrateCapReached()).to.equal(false);
        await oldWeirdo.connect(weirdo5).approve(migrationAddress, 1000000);
        await migration.connect(weirdo5).migrate();
        expect(await migration.isMigrateCapReached()).to.equal(false);
        await oldWeirdo.connect(weirdo6).approve(migrationAddress, 1000000);
        await migration.connect(weirdo6).migrate();
        expect(await migration.isMigrateCapReached()).to.equal(true);
        expect(await oldWeirdo.balanceOf(weirdo1)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo1)).to.equal(20000000);
        expect(await oldWeirdo.balanceOf(weirdo2)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo2)).to.equal(50000000);
        expect(await oldWeirdo.balanceOf(weirdo3)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo3)).to.equal(25000000);
        expect(await oldWeirdo.balanceOf(weirdo4)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo4)).to.equal(69000);
        expect(await oldWeirdo.balanceOf(weirdo5)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo5)).to.equal(100000000);
        expect(await oldWeirdo.balanceOf(weirdo6)).to.equal(0);
        expect(await newWeirdo.balanceOf(weirdo6)).to.equal(120000000);
        expect(await oldWeirdo.balanceOf(migrationAddress)).to.equal(315069);
        expect(await migration.getTotalMigrated()).to.equal(315069);
        expect(await migration.getMigrants()).to.equal(6);
        expect(await migration.isMigrationOpened()).to.equal(true);
    });

});

