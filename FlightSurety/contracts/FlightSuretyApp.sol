pragma solidity ^0.5.0;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)
    FlightSuretyData flightSuretyData;
    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    // number of airlines needed before a concensus is need
    uint constant MIN_NUM_AIRLINES_FOR_CONCENSUS = 4;

    // insurance 
    uint256 constant INSURANCE_COST = 1 ether;

    uint256 constant FUNDING_AMOUNT_REQUIRED = 10 ether;

    /********************************************************************************************/
    /*                                           EVENTS                                         */
    /********************************************************************************************/

    event AirlineRegistered(address _airlineAddress);
    event AirlineFunded(address _airlineAddress, uint256 _amount, bool _isFullyFunded);
    event FlightRegistered(bytes32 key);
    event PassengerPurchasedInsurance(address passenger, bytes32 flightKey);

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    modifier requireIsOperational() {
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "App: Caller is not contract owner");
        _;
    }

    modifier requireIsAirline() {
        require(flightSuretyData.isAirline(msg.sender), "Caller is not registered airline");
        _;
    }

    modifier requireIsFullyFundedAirline() {
        require(flightSuretyData.isAirlineFunded(msg.sender), "Airline is not funded.");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/
    constructor(address payable _dataContract) public {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(_dataContract);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() external view  returns(bool)  {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    function getNumberOfRegisteredAirlines() external view  returns(uint256)  {
        return flightSuretyData.getNumberOfRegisteredAirlines();  
    }

    function getNumberOfFundedAirlines() external view returns(uint256)  {
        return flightSuretyData.getNumberOfFundedAirlines();  
    }

    function getContractBalance() external view returns(uint256) {
        return flightSuretyData.getContractBalance();
    }

    function getInsuranceBalance() external view returns(uint256) {
        return flightSuretyData.getInsuranceBalance();
    }

    function isAirlineRegistered(address _address) external view returns(bool) {
        return flightSuretyData.isAirlineRegistered(_address);
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/
  
    function registerAirline (address _address) external payable requireIsOperational requireIsFullyFundedAirline {
        require(!flightSuretyData.isAirlineRegistered(_address), "Airline is already a registered.");
        require(!flightSuretyData.hasAirlineAlreadyVoted(_address, msg.sender), "Airline cannot vote twice for same airline");

        uint256 numberOfFundedAirlines = flightSuretyData.getNumberOfFundedAirlines();
        uint256 numberOfVotesForAirline = flightSuretyData.getNumberOfVotesForAirline(_address) + 1;
        bool _isAirlineRegistered = false;

        if ( numberOfFundedAirlines < MIN_NUM_AIRLINES_FOR_CONCENSUS ||
            (numberOfFundedAirlines == MIN_NUM_AIRLINES_FOR_CONCENSUS && numberOfVotesForAirline >= numberOfFundedAirlines.div(2))) {
                flightSuretyData.registerAirline(_address, msg.sender, true);
                _isAirlineRegistered = true;
        } else {
            flightSuretyData.registerAirline(_address, msg.sender, false);
        }
        emit AirlineRegistered(_address);
    }

    function fundAirline() external payable requireIsOperational requireIsAirline {
        flightSuretyData.fund(msg.sender, msg.value, FUNDING_AMOUNT_REQUIRED);
        emit AirlineFunded(msg.sender, msg.value, flightSuretyData.isAirlineFunded(msg.sender));
    }

    function registerFlight ( string calldata _flightName, uint256 _flightDateTime ) external requireIsOperational requireIsFullyFundedAirline {
        bytes32 key = createFlightKey(msg.sender, _flightName, _flightDateTime);
        require(!flightSuretyData.isFlightRegistered(key), "This flight is already registered");
        flightSuretyData.registerFlight(key, msg.sender, _flightDateTime, _flightName, STATUS_CODE_UNKNOWN);
        emit FlightRegistered(key);
    }

    function getCurrentFlights() external view requireIsOperational returns(bytes32[] memory) {
        return flightSuretyData.getCurrentFlights();
    }

    function getFlightInformation(bytes32 flightKey) external view requireIsOperational returns (string memory flightName, uint256 flightDateTime, address airline, uint8 status) {
        return flightSuretyData.getFlightData(flightKey);
    }

    function createFlightKey(address airline, string memory flight, uint256 timestamp) pure internal returns(bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    function purchaseInsurance(bytes32 _flightKey) external payable requireIsOperational {
        require(msg.value <= INSURANCE_COST, "The cost of insurance is 1 ether");
        flightSuretyData.purchaseInsurance(msg.sender, msg.value, _flightKey);
        emit PassengerPurchasedInsurance(msg.sender, _flightKey);
    }

    function payoutFunds() external payable requireIsOperational {
        flightSuretyData.payoutFunds(msg.sender);
    }

    function getFlightStatus(bytes32 _flightKey) external requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);
        (string memory flightName, uint256 flightDateTime, address airline, ) = flightSuretyData.getFlightData(_flightKey);
        bytes32 key = keccak256(abi.encodePacked(index, airline, flightName, flightDateTime));
        oracleResponses[key] = ResponseInfo({
                                    requester: msg.sender,
                                    isOpen: true});
        emit OracleRequest(index, airline, flightName, flightDateTime);
    }
    
   /**
    * @dev Called after oracle has updated flight status
    *
    */
    function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode) public requireIsOperational {
        bytes32 key = createFlightKey(airline, flight, timestamp);
        (, , , uint8 _status) = flightSuretyData.getFlightData(key);
        require(_status == 0, "This flight has already been processed");
        flightSuretyData.setFlightStatus(key, statusCode);

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.processFlightStatus(key, true);
        } else {
            flightSuretyData.processFlightStatus(key, false);
        }
    }

//// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 5 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    event OracleRegistered(address oracle);
    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    event FlightProcessed(address airline, string flight, uint256 timestamp, uint8 statusCode);


    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
        flightSuretyData.processPayment(msg.value);
        emit OracleRegistered(msg.sender);
    }

    function getMyIndexes() view external returns(uint8[3] memory) {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");
        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string calldata flight, uint256 timestamp, uint8 statusCode) external {
        require(oracles[msg.sender].isRegistered, "Oracle must be registered");
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            // oracleResponses[key].isOpen = false;
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
            emit FlightProcessed(airline, flight, timestamp, statusCode);
        }
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }
}   
