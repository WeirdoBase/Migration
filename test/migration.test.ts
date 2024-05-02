import { ethers } from "hardhat";
import { expect } from "chai";
import {Ownable__factory} from "../typechain-types";

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

    describe("test all getters", function() {

    it("should return the correct address of the old Weirdo token", async function() {
        expect(await migration.getOldWeirdo()).to.equal(oldWeirdoAddress);
    });

    it("should return the correct address of the new Weirdo token", async function() {
        expect(await migration.getNewWeirdo()).to.equal(newWeirdoAddress);
    });

    it("should initially report that the migration cap has not been reached", async function() {
        expect(await migration.isMigrateCapReached()).to.equal(false);
    });

    it("should return the correct treasury address", async function() {
        expect(await migration.getTreasury()).to.equal(treasury);
    });

    it("should return the zero address for the UniV2Router", async function() {
        expect(await migration.getUniV2Router()).to.equal(ethers.ZeroAddress);
    });

    it("should return the correct inflation rate", async function() {
        expect(await migration.getInflation()).to.equal(1000);
    });

    it("should return the total migrated as zero initially", async function() {
        expect(await migration.getTotalMigrated()).to.equal(0);
    });

    it("should return the number of migrants as zero initially", async function() {
        expect(await migration.getMigrants()).to.equal(0);
    });

    it("should return the correct time cap for the migration", async function() {
        const now: any = (await ethers.provider.getBlock('latest'))?.timestamp;
        const thirtyDaysInSeconds = 30 * 24 * 60 * 60;
        const expectedTimeCap = now + thirtyDaysInSeconds;
        const marginOfError = 600;  // 10 minutes in seconds
        const actualTimeCap = await migration.getTimeCap();
        expect(actualTimeCap).to.be.closeTo(expectedTimeCap, marginOfError);
    });

    it("should return the correct migrate cap", async function() {
        expect(await migration.getMigrateCap()).to.equal(200000);
    });

    it("should return the correct tax rate", async function() {
        expect(await migration.getTaxRate()).to.equal(42);
    });

    it("should initially report that the migration is open", async function() {
        expect(await migration.isMigrationOpened()).to.equal(true);
    });

    it("should return the correct owner of the contract", async function() {
        expect(await migration.owner()).to.equal(treasury);
    });
    });

    describe("Manual Migration Closure Tests", function() {
        let thirtyDaysInSeconds = 30 * 24 * 60 * 60;

        it("should not allow ending the migration prematurely", async function() {
            await expect(migration.connect(treasury).endMigration())
                .to.be.revertedWithCustomError(migration, 'MilestonesNotReached');
        });

        it("should revert when non-owner tries to end the migration", async function() {
            await ethers.provider.send("evm_increaseTime", [thirtyDaysInSeconds]);
            await ethers.provider.send("evm_mine", []);

            const currentTime = (await ethers.provider.getBlock('latest'))?.timestamp;
            const migrationTimeCap = await migration.getTimeCap();
            expect(currentTime).to.be.greaterThanOrEqual(migrationTimeCap);
            // Assuming 'deployer' is not the 'treasury' and does not have permission to end migration
            await expect(migration.connect(deployer).endMigration())
                .to.be.reverted;
        });

        it("should allow the treasury to end the migration after the time cap", async function() {
            await ethers.provider.send("evm_increaseTime", [thirtyDaysInSeconds]);
            await ethers.provider.send("evm_mine", []);

            const currentTime = (await ethers.provider.getBlock('latest'))?.timestamp;
            const migrationTimeCap = await migration.getTimeCap();
            expect(currentTime).to.be.greaterThanOrEqual(migrationTimeCap);
            await expect(migration.connect(treasury).endMigration())
                .to.not.be.reverted;
        });

        it("should confirm the migration is closed", async function() {
            await ethers.provider.send("evm_increaseTime", [thirtyDaysInSeconds]);
            await ethers.provider.send("evm_mine", []);

            const currentTime = (await ethers.provider.getBlock('latest'))?.timestamp;
            const migrationTimeCap = await migration.getTimeCap();
            expect(currentTime).to.be.greaterThanOrEqual(migrationTimeCap);
            await expect(migration.connect(treasury).endMigration())
                .to.not.be.reverted;
            expect(await migration.isMigrationOpened()).to.equal(false);
        });
    });

    describe("Migration tests", function() {
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
        const now: any = (await ethers.provider.getBlock('latest'))?.timestamp;
        const fortyTwoHoursInSeconds = 42 * 60 * 60;
        const expectedTimeCap = now + fortyTwoHoursInSeconds;
        const marginOfError = 600;  // 10 minutes in seconds
        const actualTimeCap = await migration.getTimeCap();
        expect(actualTimeCap).to.be.closeTo(expectedTimeCap, marginOfError);
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

    describe("Automatic Migration Closing Test", function() {
        it("get to migration closure", async function () {
            // weirdo1 gives allowance to the migration contract
            await oldWeirdo.connect(weirdo7).approve(migrationAddress, 1000000);
            await migration.connect(weirdo7).migrate();
            expect(await migration.isMigrateCapReached()).to.equal(true);
            const now: any = (await ethers.provider.getBlock('latest'))?.timestamp;
            const fortyTwoHoursInSeconds = 42 * 60 * 60;
            const expectedTimeCap = now + fortyTwoHoursInSeconds;
            const marginOfError = 600;  // 10 minutes in seconds
            const actualTimeCap = await migration.getTimeCap();
            expect(actualTimeCap).to.be.closeTo(expectedTimeCap, marginOfError);
            expect(await migration.isMigrationOpened()).to.equal(true);
            // can still migrate for 42 hours
            await oldWeirdo.connect(weirdo1).approve(migrationAddress, 1000000);
            await migration.connect(weirdo1).migrate();
            // 42 hours passing
            await ethers.provider.send("evm_increaseTime", [fortyTwoHoursInSeconds]);
            await ethers.provider.send("evm_mine", []);
            // weirdo will close the migration
            expect(await migration.isMigrationOpened()).to.equal(true);
            await oldWeirdo.connect(weirdo2).approve(migrationAddress, 1000000);
            await migration.connect(weirdo2).migrate();
            expect(await migration.isMigrationOpened()).to.equal(false);
            // weirdo didn't migrate
            expect(await oldWeirdo.balanceOf(weirdo2)).to.equal(50000);
            expect(await newWeirdo.balanceOf(weirdo2)).to.equal(0);
            // weirdo try migrating again and gets rejected
            await expect(migration.connect(weirdo2).migrate()).to.be.revertedWithCustomError(migration, 'OnlyWhenMigrationOpened');
        });
    });




});

