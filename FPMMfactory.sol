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
    mapping(address => uint[]) AllHoldings;

    uint256 sumofshortholdings;
    uint256 sumoflongholdings;
    uint256 sumofallholdings;

    address[] public addresses;
    uint counter;

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
        counter = 0;

        sumoflongholdings = 0;
        sumofshortholdings = 0;
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

        addresses[counter] = address(newFpmm);
        counter++;

        newFpmm.transferOwner(msg.sender);

        return address(newFpmm);
    }

    function getAddressByQuestionId(bytes32 _questionId)
        public
        view
        returns (address)
    {
        return questionIdToFpmmAddress[_questionId];
    }

    function getAllHoldingValues() public returns(uint256) {
        uint i;
        for (i = 0 ; i < 100 ; i++)
        {
            FixedProductMarketMaker fpmm = FixedProductMarketMaker(addresses[i]);

            AllHoldings[addresses[i]] = fpmm.getHoldingValues(msg.sender) ;

            sumofshortholdings += fpmm.getHoldingValues(msg.sender)[1];
            sumoflongholdings += fpmm.getHoldingValues(msg.sender)[0];



        }

        sumofallholdings = sumofshortholdings + sumoflongholdings ;

        return sumofallholdings;
    }

    
}

