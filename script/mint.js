const { ethers, getNamedAccounts } = require("hardhat")

async function main() {
    const { deployer } = await getNamedAccounts()
    const randomNFT = await ethers.getContractAt(
        "RandomNFT",
        (await deployments.get("RandomNFT")).address,
    )
    console.log(`Got contract RandomNFT at ${randomNFT.target}`)
    console.log("Minting NFT...")
    const transactionResponse = await randomNFT.requestNft({
        value: ethers.parseEther("0.001"),
    })
    await transactionResponse.wait()

    console.log("Minted!")
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error)
        process.exit(1)
    })
