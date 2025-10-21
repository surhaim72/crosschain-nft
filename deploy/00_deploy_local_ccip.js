module.exports=async({getNamedAccounts,deployments})=>{
     const {firstAccount} = await getNamedAccounts()
     const {deploy,log} = deployments

     log("CCIPLocalSimulator deploying...")
     await deploy("CCIPLocalSimulator",{
         from: firstAccount,
         log: true,
         args: []
     }) 
     log("CCIPLocalSimulator contract deployed successfully")    

}
module.exports.tags = ["test","all"]