Package.describe({
  name: 'mrvictorn:beth',
  version: '0.0.1',
  // Brief, one-line summary of the package.
  summary: 'Bootstraps Ethereum solidity contracts',
  // URL to the Git repository containing the source code for this package.
  git: '',
  // By default, Meteor will default to using README.md for documentation.
  // To avoid submitting documentation, set this field to null.
  documentation: 'README.md'
});

Package.onUse(function(api) {
  api.versionsFrom('1.1.0.3');
  api.use('mongo');
  api.use('coffeescript');
  api.use('raix:eventemitter');
  api.use('ethereum:web3');
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

