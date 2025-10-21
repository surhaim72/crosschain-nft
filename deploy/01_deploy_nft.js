module.exports=async({getNamedAccounts,deployments})=>{
     const {firstAccount} = await getNamedAccounts()
     const {deploy,log} = deployments

     log("MyToken deploying...")

     await deploy("MyToken",{
         from: firstAccount,
         log: true,
         args: ["MyToken", "MT"]
     }) 
     log("MyToken contract deployed successfully")    

}
module.exports.tags = ["sourcechain","all"]
