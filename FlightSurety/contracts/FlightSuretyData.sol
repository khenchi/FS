pragma solidity ^0.5.0;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;          // Blocks all state changes throughout the contract if false
    mapping(address => bool) private authorizedCallers;

    struct Airline {
        bool isRegistered;
        bool isFunded;
        uint256 funds;
        uint256 numberOfVotesReceived;
        mapping (address => bool) otherAirlineVotes; 
    }

    mapping(address => Airline) private airlines;

    uint256 private _numberOfRegisteredAirlines = 0;
    uint256 private _numberOfFundedAirlines = 0;

    // Flight struct
    struct Flight {
        string flightName;
        uint256 flightDateTime;
        address airline;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address[] insuredPassengers;
    }

    // string mapping to flight
    mapping(bytes32 => Flight) private flights;
    bytes32[] private currentFlights;

    // passenger with multiply flights
    struct Passenger {
        mapping(bytes32 => bool) passengerOnFlight;
        mapping(bytes32 => uint256) insuranceAmountForFlight;
        uint256 balance;
    }

    mapping(address => Passenger) passengers;

    // the contract holds balance of insurance
    uint256 private _contractBalance = 0 ether;

    // so we don't go in the hole
    uint256 private _insuranceBalance = 0 ether;


    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/
    event ContractDeauthorized(address _contractId);
    event ContractAuthorized(address _contractId);
    event OperationalStatusChanged(bool _state);

    constructor(address airline) public payable {
        contractOwner = msg.sender;
        _contractBalance = _contractBalance.add(msg.value);
        _registerAirline (airline, msg.sender, true);
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Data: Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized() {
        require(authorizedCallers[msg.sender] || (msg.sender == contractOwner), "Caller is not authorised");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/
    function isOperational() public view returns(bool) {
        return operational;
    }

    function getContractOwner() public view returns (address) {
        return contractOwner;
    }

    function isFlightRegistered(bytes32 key) external view returns(bool) {
        return flights[key].airline != address(0);
    }

    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */
    function setOperatingStatus ( bool mode ) external requireContractOwner {
        require(mode != operational, "Can't set same state more than once");
        operational = mode;
        emit OperationalStatusChanged(mode);
    } 

    function authorizeCaller(address contractAddress) external requireContractOwner{
        require(authorizedCallers[contractAddress] == false, "Address has already be registered");
        authorizedCallers[contractAddress] = true;
        emit ContractAuthorized(contractAddress);
    }

    function deauthorizeCaller(address contractAddress) external requireContractOwner {
        require(authorizedCallers[contractAddress] == true, "Address is not registered");
        delete authorizedCallers[contractAddress];
        emit ContractDeauthorized(contractAddress);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
    function isAirline( address _address) external view returns(bool) {
        return airlines[_address].isRegistered;
    }

    function hasAirlineAlreadyVoted(address _address, address _registeredAirline) external view requireIsOperational requireIsCallerAuthorized returns(bool) {
        return airlines[_address].otherAirlineVotes[_registeredAirline];
    }

    function registerAirline(address _address, address _registeredAirline, bool _isRegistered) external requireIsOperational requireIsCallerAuthorized {
       _registerAirline(_address, _registeredAirline, _isRegistered);
    }

    function _registerAirline(address _address, address _registeredAirline, bool _isRegistered) private {
        airlines[_address].otherAirlineVotes[_registeredAirline] = true;
        airlines[_address].isRegistered = _isRegistered;
        if(airlines[_address].isRegistered) {
            _numberOfRegisteredAirlines = _numberOfRegisteredAirlines.add(1);
        }
        airlines[_address].numberOfVotesReceived = airlines[_address].numberOfVotesReceived.add(1);
    }

    function isAirlineRegistered(address _airline) public view requireIsOperational returns (bool success) {
        return airlines[_airline].isRegistered;
    }

    function unregisterAirline(address _address) external requireIsOperational  {
        delete airlines[_address];
    }

    function getNumberOfRegisteredAirlines() external view requireIsOperational returns(uint256 _count) {
        return _numberOfRegisteredAirlines;
    }

    function getNumberOfFundedAirlines() external view requireIsOperational returns(uint256 _count) {
        return _numberOfFundedAirlines;
    }

    function getNumberOfVotesForAirline(address _address) external view requireIsOperational returns(uint256) {
        return airlines[_address].numberOfVotesReceived;
    }

    function getContractBalance() external view requireIsOperational returns(uint256) {
        return _contractBalance;
    }

    function getInsuranceBalance() external view requireIsOperational returns(uint256) {
        return _insuranceBalance;
    }

    function registerFlight(bytes32 key, address airline, uint256 flightDateTime, string calldata flightName, uint8 statusCode) external requireIsOperational requireIsCallerAuthorized {
        flights[key].airline = airline;
        flights[key].flightDateTime = flightDateTime;
        flights[key].flightName = flightName;
        flights[key].statusCode = statusCode;
        currentFlights.push(key);
    }

    function getFlightData(bytes32 key) external view requireIsOperational requireIsCallerAuthorized returns(string memory flightName, uint256 flightDateTime, address airline, uint8 status) {
        require(flights[key].airline != address(0));
        return (flights[key].flightName, flights[key].flightDateTime, flights[key].airline, flights[key].statusCode);
    }

    function getCurrentFlights() external view requireIsOperational requireIsCallerAuthorized returns (bytes32[] memory ) {
        return currentFlights;
    }

    function setFlightStatus(bytes32 key, uint8 status) external requireIsOperational requireIsCallerAuthorized{
        require(status != flights[key].statusCode, "Status code already set");
        flights[key].statusCode = status;
    }

    function _removeFlightFromCurrentFlights(bytes32 key) private {
        uint256 index = 0;
        bool foundKey = false;

        while(index < currentFlights.length - 1) {
            if(currentFlights[index] == key) {
                foundKey = true;
            }
            if(foundKey) {
                currentFlights[index] = currentFlights[index + 1];
            }
            index++;
        }
        if(foundKey) {
            currentFlights.length--;
        }
    }

    function isAirlineFunded(address _airline) public view requireIsOperational returns (bool success) {
        return airlines[_airline].isFunded;
    }

    function fund (address _address, uint256 _fund, uint256 FUNDING_AMOUNT_REQUIRED) public payable requireIsOperational {
        airlines[_address].funds = airlines[_address].funds.add(_fund);
        if(!airlines[_address].isFunded && airlines[_address].funds >= FUNDING_AMOUNT_REQUIRED) {
            airlines[_address].isFunded = true;
            _numberOfFundedAirlines = _numberOfFundedAirlines.add(1);
        }
        _contractBalance = _contractBalance.add(_fund);
    }

    function purchaseInsurance(address passenger, uint256 insuranceAmount, bytes32 flightKey) external payable requireIsOperational requireIsCallerAuthorized {
        require(!passengers[passenger].passengerOnFlight[flightKey], "Passenger already insured");
        passengers[passenger].passengerOnFlight[flightKey] = true;
        flights[flightKey].insuredPassengers.push(passenger);
        passengers[passenger].insuranceAmountForFlight[flightKey] = insuranceAmount.div(2) + insuranceAmount;
        _insuranceBalance = _insuranceBalance.add(passengers[passenger].insuranceAmountForFlight[flightKey]);
        _contractBalance = _contractBalance.sub(insuranceAmount.div(2));
    }

    function processPayment(uint256 value) external payable requireIsOperational requireIsCallerAuthorized {
        _contractBalance = _contractBalance.add(value);
    }

    function() external payable {
        _contractBalance = _contractBalance.add(msg.value);
    }

    function processFlightStatus(bytes32 flightKey, bool wasLateAirline) external requireIsOperational requireIsCallerAuthorized {
        uint256 passenger;
        uint256 payableAmount;
        if(wasLateAirline) {
            for(passenger = 0; passenger < flights[flightKey].insuredPassengers.length; passenger++) {
                if(passengers[flights[flightKey].insuredPassengers[passenger]].passengerOnFlight[flightKey]) {
                    payableAmount = passengers[flights[flightKey].insuredPassengers[passenger]].insuranceAmountForFlight[flightKey];
                    passengers[flights[flightKey].insuredPassengers[passenger]].insuranceAmountForFlight[flightKey] = 0;
                    passengers[flights[flightKey].insuredPassengers[passenger]].balance = passengers[flights[flightKey].insuredPassengers[passenger]].balance.add(payableAmount);
                    _insuranceBalance = _insuranceBalance.sub(payableAmount);
                }
            }
            flights[flightKey].insuredPassengers.length = 0;
        } else {
            for(passenger = 0; passenger < flights[flightKey].insuredPassengers.length; passenger++) {
                if(passengers[flights[flightKey].insuredPassengers[passenger]].passengerOnFlight[flightKey]) {
                    payableAmount = passengers[flights[flightKey].insuredPassengers[passenger]].insuranceAmountForFlight[flightKey];
                    passengers[flights[flightKey].insuredPassengers[passenger]].insuranceAmountForFlight[flightKey] = 0;
                    _contractBalance = _contractBalance.add(payableAmount);
                    _insuranceBalance = _insuranceBalance.sub(payableAmount);
                }
            }
            flights[flightKey].insuredPassengers.length = 0;
        }
        _removeFlightFromCurrentFlights(flightKey);
    }

    function payoutFunds(address payable payee) external payable requireIsOperational requireIsCallerAuthorized {
        require(passengers[payee].balance > 0, "Must have funds to get paid");
        uint256 balanceOwed = passengers[payee].balance;
        passengers[payee].balance = 0;
        payee.transfer(balanceOwed);
    }
}