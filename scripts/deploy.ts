import hre from "hardhat";
import config from "../config.json";
import fs from "fs";

async function main() {
    // Compile contracts
    await hre.run("compile");

    // Deploy and setup pool contract
    const poolConfig = {
        periodLength: 60 * 60,
        cooldownLength: 20 * 60,
        restakeReward: 1,
    };
    const Pool = await hre.ethers.getContractFactory("VPool");
    const pool = await Pool.deploy(...Object.values(poolConfig));
    await pool.deployed();
    console.log(`Value pool deployed to ${config.scannerUrl}${pool.address}`);
    config.poolAddress = pool.address;

    await pool.approveToken(config.daiAddress);
    await pool.approveToken(config.booAddress);
    console.log("Approved both DAI and BOO for use with the pool");

    // Deploy and setup the oracle contract
    const oracleConfig = {
        decimals: 1e6,
    };
    const Oracle = await hre.ethers.getContractFactory("Oracle");
    const oracle = await Oracle.deploy(...Object.values(oracleConfig));
    await oracle.deployed();
    console.log(`Oracle deployed to ${config.scannerUrl}${oracle.address}`);
    config.oracleAddress = oracle.address;

    for (const address of config.routerAddresses) {
        await oracle.addRouter(address);
    }
    console.log("Added routers to Oracle");

    // Deploy and setup the margin contract
    const marginConfig = {
        oracle: oracle.address,
        minBorrowPeriod: 5 * 60,
        maxInterestPercent: 5,
        minMarginLevel: 5,
    };
    const Margin = await hre.ethers.getContractFactory("Margin");
    const margin = await Margin.deploy(...Object.values(marginConfig));
    await margin.deployed();
    console.log(`Margin deployed to ${config.scannerUrl}${margin.address}`);
    config.marginAddress = margin.address;

    // Save the data to the config
    fs.writeFileSync("config.json", JSON.stringify(config));
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });