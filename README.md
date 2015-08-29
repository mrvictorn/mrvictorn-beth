#Package Beth
##Bootstrap Your Meteor Dapp with Ethereum Contracts autodeployment 
### Usage of package:

    meteor add mrvictorn:beth

This will add global object EthContracts

EthContracts uses web3 to connect to node defined by nodeUrl

After meteor app starts, it looks for solidity files (*.sol) in folder private/contracts, compiles them and deployes.

It uses MD5 hashes of (*.sol) files to control version updates, compiles only if file was changed, then analyses if
contract code was changed, after that deployes newly compiled files to Ethereum. Since that process takes some time,
Your code will be informed by callback just after successful deployment.


To use EthContracts on both client and server add

        Meteor.startup ()->
            EthContracts.Bootstrap nodeUrl
        #then where ever You need contact object, just call
        EthContracts.getContract 'MySuperContract' , callback 
        # callback = (err,contract)->  # node style callback parameters used here
                    
**Hint:** 'nodeUrl' can be defferent on client and on server

and by default it points to 'http://localhost:8101' (suits for local development environment)
 
**For production stage You have to define 'nodeUrl' as real url**, 

because actually in 99,9% of cases we don`t have an Ethereum node running on client!

Tunneling via socket from client to server is in backlog for future version (will come in 1.0)

###Beth API:

####EthContract object appears in global namespace, to init bootstrap just call

    EthContract.bootstrap nodeAddr, contactsDirPath, deployGas
    # default params values:
    # nodeAddr = 'http://localhost:8101' #is actual on client and server sides!
    ## serverside only parameters:
    # contactsDirPath = 'contracts' # actually 'contracts' must be placed inside private/ folder by Meteors folder convention
    # deployGas = 400000 # define Yor expected gas for deployment
    
####EthContract emits some useful events, Your code can subscribe to:
 
#####Server/Client side events: 

    EthContract.on 'nodeConnected', callback() # called on successful connect to Ethereum node 
       
    EthContract.on 'nodeConnectError', callback() # called on connection error, 
    # here You can try to reconnect or use other nodeUrl by call
        EthContracts.Bootstrap newNodeUrl
        
    EthContracts.getContract 'MySuperContract' , callback 
    # callback = (err,contract)->  # node.js style callback parameters used here    
    # contract.deployVersion == deployed source version number, is incremented by every next deployment
 

#####Server side only events: 

    EthContract.on 'compileError', callback(err) # called on file compile errors 
    # err contains short description of error
    # details will be added in future releases, possibly at 1.0-RC
       
    EthContract.on 'deployError', callback(err) # called on deployment error, 
    # err contains short description of error
    # details will be added in future releases, possibly at 1.0-RC
          

###TODO backlog
    
    0.Write extensive documentation, sample demo
    1.Write tests
    2.Add to serverside errors full description, filename, contract name, etc..
    3.Create client-server tunnel provider
    4.Create Mongol like tool for contracts to be watched on client
    5.Get feedback and ideas from community
    6.Try to suicide old versions of contracts if version changes
    7.Fix code to run on Windows environment
    8.Fix possible bugs, prepare 1.0 release candidate

###Post issues and suggestions here at [mrvictorn:beth github repo](https://github.com/mrvictorn/beth/issues)
 
