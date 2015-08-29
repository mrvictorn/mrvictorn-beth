###
  Package Beth main code
  author: Viktor Nesterenko <v@vkafe.org>
  license: "MIT"
  August, 2015
###


##TODO check path for production enviroment
##TODO alter path for Windows enviroment

ADD_PATH_TO_ROOT_DIR = '../../../../../private/'

#FYI collection.deployedContracts contains
# deployedcontract = [
#    {
#     name:
#     address:
#     code:
#     codeHash:
#     deployVersion:
#     abi:
#   },...
# ]
_loadContractByAddress = (abi,address)->
  if web3.isConnected()
    Contract = web3.eth.contract abi
    return Contract.at address
  else
    return null


class EthereumContracts extends EventEmitter
  defaultAccount: String
  deployedContracts: {} # to use on server side
  systemContracts: new Mongo.Collection 'deployedContracts' # to use on client/server sides (abi,code,address)
#  constructor: (@ethNodeAddress = 'http://localhost:8101', @debug = false) ->
#    @connect2Node ethNodeAddress
  bootstrap: (@ethNodeAddress = 'http://localhost:8101')->
    @connect2Node @ethNodeAddress
    @startObservingDeployedContracts()
  connect2Node: (nodeUrl) ->
    web3.setProvider new web3.providers.HttpProvider(nodeUrl)
    if web3.isConnected()
      @defaultAccount = web3.eth.coinbase
      @emit 'nodeConnected'
    else
      @emit 'nodeConnectError'
  getContract: (contractName,callback) =>
    unless contractName and _.isString contractName
      return callback 'Error contractName is undefined'
    oContract = deployedContracts[contractName]
    if oContract then return callback null, oContract
    @once "contractReady#{contractName}", (contract)->
      callback null, contract

  setDeployedContract: (oContract)=>
    # minimal checks
    {name,contract} = oContract
    if name and (_.isString name) and contract
      @deployedContracts[name] = contract
      @emit "contractReady#{name}", contract
      return contract
    else
      return null

  contractObjConstructor: (oContractStruct)=>
    {abi,address,name,deployVersion} = oContractStruct
    if abi and address and name
      oContract = _loadContractByAddress abi,address
      oContract.deployVersion = deployVersion
      @setDeployedContract
        name:name
        contract:oContract

  setDeployedContracts: ()=>
    contracts2load = @systemContracts.find({}).fetch()
    @contractObjConstructor contrObj for contrObj in contracts2load
    return

  startObservingDeployedContracts: ()=>
    self = @
    self.systemContracts.find({}).observeChanges
        added: (id, doc) ->
          #console.log 'added: ',doc
          self.contractObjConstructor doc
    if Meteor.isServer
      Meteor.publish 'deployedContracts', ()->
        #TODO limit publishing to only needed on client fields here!
        return EthContracts.systemContracts.find {},
          fields:
            type: false
            code: false
            codeHash: false
      #debugger
      self.setDeployedContracts()
    else
      Meteor.subscribe 'deployedContracts', ()->
        self.setDeployedContracts()

if Meteor.isClient
  EthContracts = new EthereumContracts
  @EthContracts = EthContracts


if Meteor.isServer #serverside magic goes below

  Fiber = Npm.require 'fibers'

  _loadSource = (dir,sourceFile) ->
    ## Use here Assets.getText
    fs.readFileSync path.join(dir,sourceFile),{encoding: 'utf-8'}

  # _getSolsList
  # returns [{fileName:file.sol},...]
  _getSolsList = (dir) ->
    fList = fs.readdirSync dir
    fileext = /(.sol)/i
    sols = ({fileName:name} for name in fList when name.match fileext )


  class EthereumContractsServer extends EthereumContracts
    systemContractsFiles: new Mongo.Collection 'contractsFiles'
    bootstrap: (nodeAddr, @contactsDirPath = 'contracts', @deployGas = 400000)->
      #debugger
      @once 'nodeConnected', @onStart
      super nodeAddr
    onStart: =>
      @compileAndDeployContracts()
  # -- check if there are some contracts in deployedContracts collection,
  # get list of contracts from ../contracts, check their hashes,
  # if hashes are different, try to compile and redeploy them
    compileAndDeployContracts: =>
      self = @
      path2ContractsFolder = ADD_PATH_TO_ROOT_DIR+@contactsDirPath
      solFilesList =  _getSolsList path2ContractsFolder
      if not solFilesList
        console.log "No solidity files found in #{path2ContractsFolder}"
        return
      solFileNames =[]
      solFilesList.forEach (oFile,i) ->
        solFileNames.push oFile.fileName
        fileBuff = _loadSource path2ContractsFolder,oFile.fileName
        if fileBuff
          solFilesList[i].sourceFileHash = CryptoJS.MD5(fileBuff).toString()
          solFilesList[i].source = fileBuff
      oldFiles = @systemContractsFiles.find({type:'sol',sourceFileName: {$in: solFileNames}}).fetch()
      oldContracts = @systemContracts.find({type:'sol'}).fetch()
      files2BeCompiled = _.filter solFilesList, (oFile) ->
        return not _.findWhere(oldFiles,{sourceFileName: oFile.fileName,sourceFileHash: oFile.sourceFileHash})
      # search for files with newhashes, and without
      #debugger
      if files2BeCompiled?.length #TODO clean it -> and Ether.connect2Node(NODE_URL)
  ## we have some work here!
        async.map files2BeCompiled, (oFile,asyncCB) ->
          if oFile.source
            self.compileContract oFile.source, (err,compiled)->
              if err then asyncCB()
              else
                contracts = []
                contrNames = Object.getOwnPropertyNames compiled;
                contrNames.forEach (contractName)->
                  compiledContr = compiled[contractName];
                  contracts.push
                    code: compiledContr.code
                    name: contractName
                    abi: compiledContr.info?.abiDefinition
                    isCompiled: true
                asyncCB(null, {type:'sol',sourceFileName:oFile.fileName,sourceFileHash:oFile.sourceFileHash, contracts:contracts});
              return
          else
            asyncCB()
        ,
          (err,data) ->
            if err then return console.log 'Got error while compiling contracts',err
            if not data?.length then return console.log 'Got no file contracts to re/deploy',data
            ## saving here compiled files to collection
            Fiber( ()->
              data.forEach (file)->
                self.systemContractsFiles.update {type:'sol',sourceFileName: file.sourceFileName},
                  $inc:
                    compiledVersion: 1
                  $set:
                    contacts:file.contracts
                    sourceFileHash: file.sourceFileHash
                ,
                  upsert: true
            ).run()
            contracts2Check = []
            contracts2Check.push file.contracts for file in data
            contracts2Check = _.flatten contracts2Check
            #console.log contracts2Check
            contractNames = []
            contracts2Check.forEach (oContract,i) ->
              contractNames.push oContract.name
              oContract.codeHash = CryptoJS.MD5(oContract.code).toString()
            contracts2Check = _.uniq contracts2Check,(el)-> el.codeHash
            oldContracts = _.filter oldContracts, (el)->
              return true if not el.address  ## old, compiled but undeployed contracts
              return false if _.indexOf(contractNames,el.name) == -1
              return true
            contracts2BeDeployed = _.filter contracts2Check, (oContract) ->
              return not _.findWhere oldContracts, {codeHash: oContract.codeHash, name: oContract.name }

            #console.log contracts2BeDeployed
            #check here for changed MD5(source) changed and not deployed contracts
            contracts2BeDeployed.forEach (oContract)->
              self.deployContract oContract ,(err,deployedContract) ->
                if err then return console.log 'Received error while deploying contract ',err,oContract
                self.setDeployedContract deployedContract
                Fiber( ()->
                  self.systemContracts.update {type:'sol',name: deployedContract.name},
                    $inc:
                      deployVersion: 1
                    $set:
                      code: deployedContract.code
                      abi: deployedContract.abi
                      codeHash: deployedContract.codeHash
                      address: deployedContract.address
                  ,
                    upsert: true
                ).run()
                return
    ##FYI .onStart end here

    compileContract: (source, cb) =>
      self = @
      web3.eth.compile.solidity source, (err, data) ->
        #console.log 'Compile result: ',err, data
        if err then self.emit 'compileError',err
        cb err, data
    deployContract: (contractStruct, cb) =>
      self = @
      contract = web3.eth.contract contractStruct.abi
      contract.new
        data: contractStruct.code
        gas: @deployGas
        from: @defaultAccount
      ,
        (err, myContract) ->
          if err
            self.emit 'deployError',err
            return cb err
          if not myContract.address
            console.log 'Contact ', contractStruct.name, ' got transaction hash:', myContract.transactionHash
          else
            contractStruct.address = myContract.address
            contractStruct.contract = myContract
            ## will emit in self.setDeployedContract
            #self.emit "contractReady#{contractStruct.name}", myContract
            cb null, contractStruct
      return


  EthContracts = new EthereumContractsServer
  @EthContracts = EthContracts



