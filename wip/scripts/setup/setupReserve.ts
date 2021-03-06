import hre from "hardhat";
import config from "../../config.json";

export default async function main() {
    const leveragePool = await hre.ethers.getContractAt("LPool", config.leveragePoolAddress);
    const reserve = await hre.ethers.getContractAt("Reserve", config.reserveAddress);

    const leveragePoolApprovedTokens = config.approved.filter((approved) => approved.leveragePool).map((approved) => approved.address);
    const lpTokens = await Promise.all(leveragePoolApprovedTokens.map((approved) => leveragePool.LPFromPT(approved)));
    const rateNumerators = Array(lpTokens.length).fill(10);
    const rateDenominators = Array(lpTokens.length).fill(100);
    await reserve.setRates(lpTokens, rateNumerators, rateDenominators);

    const approved = Array(leveragePoolApprovedTokens.length).fill(true);
    await reserve.setApproved(leveragePoolApprovedTokens, approved);

    console.log("Setup: Reserve");
}

if (require.main === module)
    main()
        .then(() => process.exit(0))
        .catch((error) => {
            console.error(error);
            process.exit(1);
        });
