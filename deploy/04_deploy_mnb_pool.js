const {getNamedAccounts} = require("hardhat")   

module.exports=async({getNamedAccounts,deployments})=>{ 

     const {firstAccount} = await getNamedAccounts()
     const {deploy,log} = deployments;

     log("NFTPoolLockAndRelease deploying...");

     // 步骤：
     // 1、NFTPoolLockAndRelease.sol文件里
     // 2、构造函数需要的参数 address _router, address _link,address ntfAddr
     // 3、怎么获取_router和_link 地址？需要从CCIPLocalSimulator 合约中获取。
     // 4、获取CCIPLocalSimulator的对象，需要在ethers.getContractAt有两个参数：合约名称、合约的地址
     // 5、deploy/00_deploy_local_ccip.js 这个部署后，就可以调用函数的参数；
     // 6、ccipsimulator.configuration()这个函数，返回的是一个对象，对象里面有很多个参数，其中我们需要的_router和_link两个参数
     // 7、获取ntfAddr地址，则从 MyToken 合约获取地址

    const ccipsimulatorDeployment = await deployments.get("CCIPLocalSimulator");
    const ccipsimulator = await ethers.getContractAt("CCIPLocalSimulator",ccipsimulatorDeployment.address);
    const ccipConfig = await ccipsimulator.configuration();
    const destinationRouter = ccipConfig.destinationRouter_;
    const linkTokenAddr = ccipConfig.linkToken_;
    const wnftDeployment = await deployments.get("WrappedNFT");
    const wnftAddr = wnftDeployment.address;

    await deploy("NFTPoolBurnAndMint",{
         contract: "NFTPoolBurnAndMint",
         from: firstAccount,
         log: true,
         args: [destinationRouter,linkTokenAddr,wnftAddr]
    })
    log("NFTPoolBurnAndMint contract deployed successfully")
}   
module.exports.tags = ["all","destchain"]
