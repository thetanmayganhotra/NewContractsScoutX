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



        addresses.push(questionIdToFpmmAddress[_questionId]);
        conditionalTokens.addAddress(questionIdToFpmmAddress[_questionId]);



        return address(newFpmm);
    }

    function getAddressByQuestionId(bytes32 _questionId)
        public
        view
        returns (address)
    {
        return questionIdToFpmmAddress[_questionId];
    }


    function getaddresslist() public view returns(address[] memory) {
        return addresses;
    } 


    function totalholdingvalueOnAllFpmms() public view returns(uint256) {
        uint256 totalholdingvalueOnAll = 0;
        for(uint i = 0 ; i < addresses.length ; i++) {
            FixedProductMarketMaker fpmm = FixedProductMarketMaker(addresses[i]);
            totalholdingvalueOnAll = totalholdingvalueOnAll + fpmm.HoldingValueTotalOnThisFpmm();


        }

        return totalholdingvalueOnAll;
    }




    
}

