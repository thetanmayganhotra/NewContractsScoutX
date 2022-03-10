// SPDX-License-Identifier: MIT


pragma solidity ^0.8.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ConditionalTokens} from "./ConditionalTokens.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { FixedProductMarketMaker} from "./FPMM(faizaan).sol";

contract FixedProductMarketMakerFactory {

   

    ConditionalTokens private conditionalTokens;

    IERC20 private collateralToken;

    bytes32[] private collectionIds;
    bytes32[] private positionIds;
    bytes32 private conditionId;
    address private oracle;
    address private admin;



    


    mapping(bytes32 => address) public questionIdtoaddress;
    mapping(bytes32 => bytes32) public questionIdtoConditionId;
    mapping(bytes32 => mapping(uint => bytes32)) public questionIdtoCollectionId;
    mapping(bytes32 => mapping(uint => bytes32)) public questionIdtoPositionId;




    event FixedProductMarketMakerCreation(
        address indexed creator,
        FixedProductMarketMaker newFactory,
        ConditionalTokens indexed conditionalTokens,
        IERC20 indexed collateralToken,
        bytes32 conditionId,
        uint fee
    );

   

    constructor(address _conditionalTokensAddr,
        address _collateralTokenAddr,address _oracle) public {

             

            conditionalTokens = ConditionalTokens(_conditionalTokensAddr);
            collateralToken = IERC20(_collateralTokenAddr);
            oracle = _oracle;
            admin = msg.sender;

        
    }

   bytes32 parentCollectionId = bytes32[0];
        
        

    modifier OnlyAdmin() {
        require(msg.sender == admin, "only admin");
        _;
    }



    function createFixedProductMarketMaker(
        string memory playername, string memory playersymbol,
        uint _fee,bytes32 _questionId)
        OnlyAdmin
        external
        returns (FixedProductMarketMaker)
    {    
        
       

        

        conditionId = conditionalTokens.getConditionId(oracle,_questionId,2);
        questionIdtoConditionId[_questionId]= conditionId;
       
       
        collectionIds[0] = conditionalTokens.getCollectionId(bytes32(0), conditionId, 1);
        collectionIds[1] = conditionalTokens.getCollectionId(bytes32(0), conditionId, 2);
        questionIdtoCollectionId[_questionId][0] = collectionIds[0];
        questionIdtoCollectionId[_questionId][1] = collectionIds[1];



        positionIds[0] = conditionalTokens.getPositionId(collateralToken, collectionIds[0]);
        positionIds[1] = conditionalTokens.getPositionId(collateralToken, collectionIds[1]);
        questionIdtoPositionId[_questionId][0] = positionIds[0]; 
        questionIdtoPositionId[_questionId][1] = positionIds[1]; 
                  

        FixedProductMarketMaker newPlayer = new FixedProductMarketMaker(playername,playersymbol,_conditionalTokensAddr,_collateralTokenAddr,_fee,oracle,_questionId);

    

        emit FixedProductMarketMakerCreation(
            msg.sender,
            newPlayer,
            conditionalTokens,
            collateralToken,
            conditionId,
            _fee
        );

        questionIdtoaddress[_questionId] = address(newPlayer);

        return newPlayer;
    }

    function getaddressbyquestionId(uint256 _questionId) public view returns(address) {
        return questionIdtoaddress[_questionId];
    }


     function getconditionIdByquestionId(uint256 _questionId)
        public
        view
        returns (bytes32)
    {
        return questionIdtoConditionId[_questionId];
    }

    function getcollectionIdByquestionId(uint256 _questionId , uint outcomeIndex)
        public
        view
        returns (bytes32)
    {
        return questionIdtoCollectionId[_questionId][outcomeIndex];
    }

    function getpositionIdByquestionId(uint256 _questionId, uint outcomeIndex)
        public
        view
        returns (bytes32)
    {
        return questionIdtoPositionId[_questionId][outcomeIndex];
    }




}