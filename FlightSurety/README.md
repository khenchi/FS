# FlightSurety

FlightSurety is a sample application project for Udacity's Blockchain course.  Below is a list of instructions to get this project up and running on your machine.

## Tool Versions
Node: 13.10.0

Truffle: v5.1.45 


## 1. Install
This repository contains Smart Contract code in Solidity (using Truffle), tests (also using Truffle), dApp scaffolding (using HTML, CSS and JS) and server app scaffolding.

To install, download or clone the repo, then:

```shell script
npm install
truffle compile
```

## 2. Bring up the ganache-cli
```shell script
ganache-cli -m "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat" -a 50 -e 10000
```
This will create 50 accounts with 10,000 ether each.  In config/testConfig.js I have included all the accounts, and their private keys, so you can grab them easily and use them in MetaMask.

## 3. Run the tests
```shell script
truffle test ./test/flightSurety.js
truffle test ./test/oracles.js
```

All tests should pass

## 4. Bring up the DAPP
```shell script
truffle migrate
npm run dapp
```

* Be sure to grab the contract address for FlightSuretyApp.sol you will need it soon

You can view the dapp at http://localhost:8000

In MetaMask set the active account to the Contract Owner account.  On the Dapp add the contract address you grabbed above.

As the contract owner you can test out toggling the operational status.

## 5. Bring up the Oracle Servers
```shell script
npm run server
```

## 6. Other things to note
The system automatically registered the first airline, but it is not funded.  The active account must be Airline1 and then press the Fund button in the Fund My Airline section.

1. Funded airlines can register a new airline.
2. Funded airlines can register a new flight.
3. Register a couple of flights for testing.
4. Have a passenger account purchase insurance for the flights created.
5. If the date/time of the flight is in the past the status from the oracles will come back as STATUS_CODE_LATE_AIRLINE.  If the date/time is in the future the oracles will return STATUS_CODE_ON_TIME.
6. Select a flight and send to oracles.  This process will determine payouts.
   1. If the flight is on time all the money set aside as insurance will be refund to the contract.
   2. If the flight is late the funds will be allocated for the passenger that purchased the insurance.  Just click collect funds, and your money will be transferred.
