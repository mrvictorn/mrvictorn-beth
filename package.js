Package.describe({
  name: 'mrvictorn:beth',
  version: '0.0.3',
  summary: 'Bootstrap Your Meteor Dapp with Ethereum Contracts autodeployment',
  git: 'https://github.com/mrvictorn/mrvictorn-beth.git',
  documentation: 'README.md'
});

Package.onUse(function(api) {
  api.versionsFrom('1.1.0.3');
  api.use('mongo');
  api.use('coffeescript');
  api.use('raix:eventemitter@0.1.3');
  api.use('ethereum:web3@0.12.2');
  api.addFiles(['bootstrapether.coffee','global.js']);
  api.export('EthContracts');
});

Package.onTest(function(api) {
  api.use('tinytest');
  api.use('mrvictorn:beth');
  api.addFiles('beth-tests.js');
});


Npm.depends({
  underscore: "1.8.3",
  async: "1.4.2",
  fibers: "1.0.4"
});

