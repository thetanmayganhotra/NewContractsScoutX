// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import { FixedProductMarketMaker } from "./FPMM.sol";




contract FixedProductMarketMakerFactory {
    ConditionalTokens private conditionalTokens;
    IERC20 private collateralToken;
    bytes32[] private collectionIds;
    uint[] private positionIds;
    bytes32 private conditionId;
    address private oracle;
    // mapping(address => uint[]) AllHoldings;
    uint256[][] AllHoldings;

    

    // bytes32[] public questionIds;
    address[] public addresses;

    address private admin;
    address private _collateralTokenAddress;
    address private _conditionalTokensAddress;
    mapping(bytes32 => address) public questionIdToFpmmAddress;
    event FixedProductMarketMakerCreation(
        address indexed creator,
        FixedProductMarketMaker newFactory,
        ConditionalTokens indexed conditionalTokens,
        IERC20 indexed collateralToken,
        bytes32 conditionId,
        uint256 fee
    );


    constructor(
        address _conditionalTokensAddr,
        address _collateralTokenAddr,
        address _oracle
    ) {
        conditionalTokens = ConditionalTokens(_conditionalTokensAddr);
        collateralToken = IERC20(_collateralTokenAddr);
        oracle = _oracle;
        admin = msg.sender;
        _collateralTokenAddress = _collateralTokenAddr;
        _conditionalTokensAddress = _conditionalTokensAddr;
      
    }

    bytes32 parentCollectionId = bytes32(0);
    modifier onlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }

    function createFixedProductMarketMaker(
        string memory lpTokenName,
        string memory lpTokenSymbol,
        uint256 _fee,
        bytes32 _questionId
    ) external onlyAdmin returns (address) {
        FixedProductMarketMaker newFpmm = new FixedProductMarketMaker(
            lpTokenName,
            lpTokenSymbol,
            _conditionalTokensAddress,
            _collateralTokenAddress,
            _questionId,
            oracle,
            _fee
        );

        emit FixedProductMarketMakerCreation(
            msg.sender,
            newFpmm,
            conditionalTokens,
            collateralToken,
            conditionId,
            _fee
        );
        questionIdToFpmmAddress[_questionId] = address(newFpmm);

        

        newFpmm.transferOwner(msg.sender);


        // questionIds.push(_questionId);
        addresses.push(questionIdToFpmmAddress[_questionId]);

        return address(newFpmm);
    }

    function getAddressByQuestionId(bytes32 _questionId)
        public
        view
        returns (address)
    {
        return questionIdToFpmmAddress[_questionId];
    }

    // function getAllHoldingValues(address _user) public returns(uint256[][] memory) {
    //     uint i;
    //     uint j ;
    //     uint256 k; 
    //     for (i = 0 ; i < questionIds.length ; i++)
    //     {
    //         FixedProductMarketMaker fpmm = FixedProductMarketMaker(questionIdToFpmmAddress[questionIds[i]]);

    //         k = uint256(questionIds[i]);
    //         for(j = 0 ; j < 2 ; j++) {

    //         AllHoldings[k][j] = fpmm.getHoldingValues(_user)[j] ;

    //         }



    //     }

    //     return AllHoldings;
    // }

    function getaddresslist() public view returns(address[] memory) {
        return addresses;
    } 

    // function getAllHoldings(address _user) public returns(uint256[][] memory) {
    //      uint i;
    //      uint j;

    //      for (i = 0 ; i < addresses.length ; i++)
    //     {
    //         FixedProductMarketMaker fpmm = FixedProductMarketMaker(addresses[i]);

    //         for(j = 0 ; j < 2 ; j++)

    //           {  AllHoldings[i][j] = fpmm.getHoldingValues(_user)[j] ; }

    //     }

    //     return AllHoldings;
    // }



    
}

