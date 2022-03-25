// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ConditionalTokens.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol";

library CeilDiv {
    // calculates ceil(x/y)
    function ceildiv(uint256 x, uint256 y) internal pure returns (uint256) {
        if (x > 0) return ((x - 1) / y) + 1;

        return x / y;
    }
}

contract FixedProductMarketMaker is ERC20, ERC1155Receiver {
    event FPMMFundingAdded(
        address indexed funder,
        uint256[] amountsAdded,
        uint256 sharesMinted
    );
    event FPMMFundingRemoved(
        address indexed funder,
        uint256[] amountsRemoved,
        uint256 collateralRemovedFromFeePool,
        uint256 sharesBurnt
    );
    event FPMMBuy(
        address indexed buyer,
        uint256 investmentAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensBought,
        bytes32 questionId,
        uint256 totalTradeVolume

    );
    event FPMMSell(
        address indexed seller,
        uint256 returnAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensSold,
        bytes32 questionId,
        uint256 totalTradeVolume
    );
    event FPMMCreated(
        address indexed creator,
        string tokenName,
        string tokenSymbol,
        address conditionalTokensAddr,
        address collateralTokensAddr,
        bytes32 conditionIds,
        uint256 fee
    );

    

    event TransferredOwner(address indexed owner, address previousOwner);

    uint256 currentshortprice;
    uint256 currentlongprice;

    event LongShortCurrentPrice(
        uint256 currentlongprice,
        uint256 currentshortprice,
        uint256 indexed timestamp,
        bytes32 indexed questionId,
        address indexed fpmm
    );
    // using SafeMath for uint;
    using CeilDiv for uint256;
    uint256 constant ONE = 10**18; // 1% == 0.01 == 10**16 == 10**16 / ONE = 10**-2 == 0.01
    address private owner;
    address private oracle;
    ConditionalTokens private conditionalTokens;
    IERC20 private collateralToken;
    uint256 private fee;
    uint256 internal feePoolWeight;
    bytes32 private conditionId;
    bytes32 private questionId;

    bytes32[] private collectionIds;
    uint256[] private positionIds;
    uint256 private longPositionId;
    uint256 private shortPositionId;
    uint256 constant numPositions = 2;
    mapping(address => uint256) withdrawnFees;
    uint256 internal totalWithdrawnFees;

    uint256 public totalliquidity;

    uint256 public longtradevolume;
    uint256 public shorttradevolume;
    uint256 public theinvestmentAmountMinusFees;
    uint256 public thereturnAmountPlusFees;
    uint256 totalTradeVolume;

    constructor(
        string memory name,
        string memory symbol,
        address _conditionalTokensAddr,
        address _collateralTokenAddr,
        bytes32 _questionId,
        address _oracle,
        uint256 _fee
    ) ERC20(name, symbol) {
        fee = _fee;
        questionId = _questionId;
        oracle = _oracle;
        collateralToken = ERC20(_collateralTokenAddr);
        conditionalTokens = ConditionalTokens(_conditionalTokensAddr);
        conditionalTokens.prepareCondition(oracle, questionId, 2);
        conditionId = conditionalTokens.getConditionId(oracle, questionId, 2);
        collectionIds = new bytes32[](2);
        collectionIds[0] = conditionalTokens.getCollectionId(
            bytes32(0),
            conditionId,
            1
        );
        collectionIds[1] = conditionalTokens.getCollectionId(
            bytes32(0),
            conditionId,
            2
        );
        longPositionId = conditionalTokens.getPositionId(
            collateralToken,
            collectionIds[0]
        );
        shortPositionId = conditionalTokens.getPositionId(
            collateralToken,
            collectionIds[1]
        );
        positionIds = new uint256[](2);
        positionIds[0] = longPositionId;
        positionIds[1] = shortPositionId;
        owner = msg.sender;
        longtradevolume = 0;
        shorttradevolume = 0;
        totalliquidity = 0;
        emit FPMMCreated(
            msg.sender,
            name,
            symbol,
            _conditionalTokensAddr,
            _collateralTokenAddr,
            conditionId,
            _fee
        );
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "Restricted to Owner.");
        _;
    }

    function transferOwner(address newOwner) public onlyOwner {
        owner = newOwner;
        emit TransferredOwner(newOwner, address(this));
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getBalancesFor(address target)
        public
        view
        returns (uint256[] memory)
    {
        address[] memory targets = new address[](2);
        targets[0] = target;
        targets[1] = target;
        return conditionalTokens.balanceOfBatch(targets, positionIds);
    }

    function getPositionIds() public view returns (uint256[] memory) {
        return positionIds;
    }

    function isOwner(address sender) public view returns (bool) {
        return sender == owner;
    }

    function getFee() public view returns (uint256) {
        return fee;
    }

    function setFees(uint256 newFees) public onlyOwner {
        fee = newFees;
    }

    function getPoolBalances() public view returns (uint256[] memory) {
        return getBalancesFor(address(this));
    }

    function generateBasicPartition(uint256 outcomeSlotCount)
        public
        pure
        returns (uint256[] memory partition)
    {
        partition = new uint256[](outcomeSlotCount);
        for (uint256 i = 0; i < outcomeSlotCount; i++) {
            partition[i] = 1 << i;
        }
    }

    function splitPositionThroughAllConditions(uint256 amount) private {
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;
        conditionalTokens.splitPosition(
            collateralToken,
            bytes32(0),
            conditionId,
            partition,
            amount
        );
    }

    function mergePositionsThroughAllConditions(uint256 amount) private {
        uint256[] memory partition = new uint256[](2);
        partition[0] = 1;
        partition[1] = 2;
        for (uint256 j = 0; j < collectionIds.length; j++) {
            conditionalTokens.mergePositions(
                collateralToken,
                bytes32(0),
                conditionId,
                partition,
                amount
            );
        }
    }

    function collectedFees() external view returns (uint256) {
        return feePoolWeight - totalWithdrawnFees;
    }

    function feesWithdrawableBy(address account) public view returns (uint256) {
        uint256 rawAmount = (feePoolWeight * (balanceOf(account))) /
            totalSupply();
        return rawAmount - withdrawnFees[account];
    }

    function withdrawFees(address account) public {
        uint256 rawAmount = (feePoolWeight * (balanceOf(account))) /
            totalSupply();
        uint256 withdrawableAmount = rawAmount - (withdrawnFees[account]);
        if (withdrawableAmount > 0) {
            withdrawnFees[account] = rawAmount;
            totalWithdrawnFees = totalWithdrawnFees + withdrawableAmount;
            require(
                collateralToken.transfer(account, withdrawableAmount),
                "withdrawal transfer failed"
            );
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (from != address(0)) {
            withdrawFees(from);
        }
        uint256 totalSupply = totalSupply();
        uint256 withdrawnFeesTransfer = totalSupply == 0
            ? amount
            : (feePoolWeight * (amount)) / totalSupply;
        if (from != address(0)) {
            withdrawnFees[from] = withdrawnFees[from] - withdrawnFeesTransfer;
            totalWithdrawnFees = totalWithdrawnFees - withdrawnFeesTransfer;
        } else {
            feePoolWeight = feePoolWeight + withdrawnFeesTransfer;
        }
        if (to != address(0)) {
            withdrawnFees[to] = withdrawnFees[to] + withdrawnFeesTransfer;
            totalWithdrawnFees = totalWithdrawnFees + withdrawnFeesTransfer;
        } else {
            feePoolWeight = feePoolWeight - withdrawnFeesTransfer;
        }
    }

    function addFunding(uint256 addedFunds, uint256[] calldata distributionHint)
        external
    {
        require(addedFunds > 0, "funding must be non-zero");
        uint256[] memory sendBackAmounts = new uint256[](numPositions);
        uint256 poolShareSupply = totalSupply();
        uint256 mintAmount;
        if (poolShareSupply > 0) {
            require(
                distributionHint.length == 0,
                "cannot use distribution hint after initial funding"
            );
            uint256[] memory poolBalances = getPoolBalances();
            uint256 poolWeight = 0;
            for (uint256 i = 0; i < poolBalances.length; i++) {
                uint256 balance = poolBalances[i];
                if (poolWeight < balance) poolWeight = balance;
            }
            for (uint256 i = 0; i < poolBalances.length; i++) {
                uint256 remaining = (addedFunds * (poolBalances[i])) /
                    poolWeight;
                sendBackAmounts[i] = addedFunds - (remaining);
            }
            mintAmount = (addedFunds * (poolShareSupply)) / poolWeight;
        } else {
            if (distributionHint.length > 0) {
                require(
                    distributionHint.length == numPositions,
                    "hint length off"
                );
                uint256 maxHint = 0;
                for (uint256 i = 0; i < distributionHint.length; i++) {
                    uint256 hint = distributionHint[i];
                    if (maxHint < hint) maxHint = hint;
                }
                for (uint256 i = 0; i < distributionHint.length; i++) {
                    uint256 remaining = (addedFunds * (distributionHint[i])) /
                        maxHint;
                    require(remaining > 0, "must hint a valid distribution");
                    sendBackAmounts[i] = addedFunds - (remaining);
                }
            }
            mintAmount = addedFunds;
        }
        require(
            collateralToken.transferFrom(msg.sender, address(this), addedFunds),
            "funding transfer failed"
        );
        require(
            collateralToken.approve(address(conditionalTokens), addedFunds),
            "approval for splits failed"
        );
        splitPositionThroughAllConditions(addedFunds);
        _mint(msg.sender, mintAmount);
        conditionalTokens.safeBatchTransferFrom(
            address(this),
            msg.sender,
            getPositionIds(),
            sendBackAmounts,
            ""
        );
        // transform sendBackAmounts to array of amounts added
        for (uint256 i = 0; i < sendBackAmounts.length; i++) {
            sendBackAmounts[i] = addedFunds - sendBackAmounts[i];
        }
        emit FPMMFundingAdded(msg.sender, sendBackAmounts, mintAmount);

        currentlongprice = getlongPrices();
        currentshortprice = getshortPrices();
        emit LongShortCurrentPrice(
            currentlongprice,
            currentshortprice,
            block.timestamp,
            questionId,
            address(this)
        );

        totalliquidity = totalliquidity + addedFunds;
    }

    function removeFunding(uint256 sharesToBurn) external {
        uint256[] memory poolBalances = getPoolBalances();
        uint256[] memory sendAmounts = new uint256[](poolBalances.length);
        uint256 poolShareSupply = totalSupply();
        for (uint256 i = 0; i < poolBalances.length; i++) {
            sendAmounts[i] =
                (poolBalances[i] * (sharesToBurn)) /
                poolShareSupply;
        }
        uint256 collateralRemovedFromFeePool = collateralToken.balanceOf(
            address(this)
        );
        _burn(msg.sender, sharesToBurn);
        collateralRemovedFromFeePool =
            collateralRemovedFromFeePool -
            collateralToken.balanceOf(address(this));
        conditionalTokens.safeBatchTransferFrom(
            address(this),
            msg.sender,
            getPositionIds(),
            sendAmounts,
            ""
        );
        emit FPMMFundingRemoved(
            msg.sender,
            sendAmounts,
            collateralRemovedFromFeePool,
            sharesToBurn
        );


        currentlongprice = getlongPrices();
        currentshortprice = getshortPrices();

      



        emit LongShortCurrentPrice(
            currentlongprice,
            currentshortprice,
            block.timestamp,
            questionId,
            address(this)
        );
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes4) {
        if (operator == address(this)) {
            return this.onERC1155Received.selector;
        }
        return 0x0;
    }

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external override returns (bytes4) {
        if (operator == address(this) && from == address(0)) {
            return this.onERC1155BatchReceived.selector;
        }
        return 0x0;
    }

    function getlongPrices() public view returns (uint256) {
        uint256 longprice;
        uint256[] memory poolBalances = getPoolBalances();
        require(
            poolBalances.length == 2,
            "incorrect number of balances in pool"
        );
        uint256 x1 = poolBalances[0];
        uint256 x2 = poolBalances[1];


        if (x1 == 0 && x2 == 0 ) {
            longprice = 0;
        }
        else {
        longprice = ((x2 * ONE) / (x1 + x2));
        }

        return longprice;
    }

    function getshortPrices() public view returns (uint256) {
        uint256 shortprice;
        uint256[] memory poolBalances = getPoolBalances();
        require(
            poolBalances.length == 2,
            "incorrect number of balances in pool"
        );
        uint256 x1 = poolBalances[0];

        uint256 x2 = poolBalances[1];
     

         if (x1 == 0 && x2 == 0 ) {
            shortprice = 0;
        }
        else {
        shortprice = ((x1 * ONE) / (x1 + x2));
        }
        return shortprice;
    }

    function calcBuyAmount(uint256 investmentAmount, uint256 outcomeIndex)
        public
        view
        returns (uint256)
    {
        require(outcomeIndex < numPositions, "invalid outcome index");

        uint256[] memory poolBalances = getPoolBalances();
        uint256 investmentAmountMinusFees = investmentAmount -
            ((investmentAmount * (fee)) / ONE);
        
        uint256 buyTokenPoolBalance = poolBalances[outcomeIndex];
        uint256 endingOutcomeBalance = buyTokenPoolBalance * (ONE);
        for (uint256 i = 0; i < poolBalances.length; i++) {
            if (i != outcomeIndex) {
                uint256 poolBalance = poolBalances[i];
                endingOutcomeBalance = (endingOutcomeBalance * poolBalance)
                    .ceildiv(poolBalance + investmentAmountMinusFees);
            }
        }

        require(endingOutcomeBalance > 0, "must have non-zero balances");

        return
            (buyTokenPoolBalance + investmentAmountMinusFees) -
            (endingOutcomeBalance.ceildiv(ONE));
    }

    function calcSellAmount(uint256 returnAmount, uint256 outcomeIndex)
        public
        view
        returns (uint256 outcomeTokenSellAmount)
    {
        require(outcomeIndex < numPositions, "invalid outcome index");

        uint256[] memory poolBalances = getPoolBalances();
        uint256 returnAmountPlusFees = (returnAmount * ONE) / (ONE - fee);
        
        uint256 sellTokenPoolBalance = poolBalances[outcomeIndex];
        uint256 endingOutcomeBalance = sellTokenPoolBalance * ONE;
        for (uint256 i = 0; i < poolBalances.length; i++) {
            if (i != outcomeIndex) {
                uint256 poolBalance = poolBalances[i];
                endingOutcomeBalance = (endingOutcomeBalance * poolBalance)
                    .ceildiv(poolBalance - returnAmountPlusFees);
            }
        }
        require(endingOutcomeBalance > 0, "must have non-zero balances");

        return
            returnAmountPlusFees +
            (endingOutcomeBalance.ceildiv(ONE)) -
            sellTokenPoolBalance;
    }

    function buy(
        uint256 investmentAmount,
        uint256 outcomeIndex,
        uint256 minOutcomeTokensToBuy
    ) external {
        uint256 outcomeTokensToBuy = calcBuyAmount(
            investmentAmount,
            outcomeIndex
        );
        require(
            outcomeTokensToBuy >= minOutcomeTokensToBuy,
            "minimum buy amount not reached"
        );
        require(
            collateralToken.transferFrom(
                msg.sender,
                address(this),
                investmentAmount
            ),
            "cost transfer failed"
        );
        uint256 feeAmount = (investmentAmount * fee) / ONE;
        feePoolWeight = feePoolWeight + feeAmount;
        uint256 investmentAmountMinusFees = investmentAmount - feeAmount;
        require(
            collateralToken.approve(
                address(conditionalTokens),
                investmentAmountMinusFees
            ),
            "approval for splits failed"
        );
        splitPositionThroughAllConditions(investmentAmountMinusFees);
        conditionalTokens.safeTransferFrom(
            address(this),
            msg.sender,
            getPositionIds()[outcomeIndex],
            outcomeTokensToBuy,
            ""
        );
        
        currentlongprice = getlongPrices();
        currentshortprice = getshortPrices();
        emit LongShortCurrentPrice(
            currentlongprice,
            currentshortprice,
            block.timestamp,
            questionId,
            address(this)
        );

        if (outcomeIndex == 0) {
            longtradevolume = longtradevolume + investmentAmount;
        } else {
            shorttradevolume = shorttradevolume + investmentAmount;
        }

        totalTradeVolume = longtradevolume + shorttradevolume;

        emit FPMMBuy(
            msg.sender,
            investmentAmount,
            feeAmount,
            outcomeIndex,
            outcomeTokensToBuy,
            questionId,
            totalTradeVolume
        );

    }

    function sell(
        uint256 returnAmount,
        uint256 outcomeIndex,
        uint256 maxOutcomeTokensToSell
    ) external {
        uint256 outcomeTokensToSell = calcSellAmount(
            returnAmount,
            outcomeIndex
        );
        require(
            outcomeTokensToSell <= maxOutcomeTokensToSell,
            "maximum sell amount exceeded"
        );
        conditionalTokens.safeTransferFrom(
            msg.sender,
            address(this),
            getPositionIds()[outcomeIndex],
            outcomeTokensToSell,
            ""
        );

        uint256 feeAmount = (returnAmount * fee) / (ONE - fee);
        feePoolWeight = feePoolWeight + feeAmount;
        uint256 returnAmountPlusFees = returnAmount + feeAmount;
        mergePositionsThroughAllConditions(returnAmountPlusFees);
        require(
            collateralToken.transfer(msg.sender, returnAmount),
            "return transfer failed"
        );
       

        currentlongprice = getlongPrices();
        currentshortprice = getshortPrices();
        emit LongShortCurrentPrice(
            currentlongprice,
            currentshortprice,
            block.timestamp,
            questionId,
            address(this)
        );

        if (outcomeIndex == 0) {
            longtradevolume = longtradevolume + returnAmount;
        } else {
            shorttradevolume = shorttradevolume + returnAmount;
        }

        totalTradeVolume = longtradevolume + shorttradevolume;


         emit FPMMSell(
            msg.sender,
            returnAmount,
            feeAmount,
            outcomeIndex,
            outcomeTokensToSell,
            questionId,
            totalTradeVolume
        );
    }

    function getlongtradevolume() public view returns (uint256) {
        return longtradevolume;
    }

    function getshorttradevolume() public view returns (uint256) {
        return shorttradevolume;
    }

    function gettotalliquidity() public view returns (uint256) {
        return totalliquidity;
    }

    function getShortHoldingValue(address _user) public view returns(uint256){

        uint256[] memory playerbalance = getBalancesFor(_user);
        uint256 holdingvalue = playerbalance[1]*currentshortprice;

        return holdingvalue;
    }

  


    function getLongHoldingValue(address _user) public view returns(uint256){
        uint256[] memory playerbalance = getBalancesFor(_user);
        uint256 holdingvalue = playerbalance[0]*currentlongprice;

        return holdingvalue;
    }

    function totalholdingvalue(address _user) public view returns(uint256) {
        uint256 total;
        total = getShortHoldingValue(_user) + getLongHoldingValue(_user);

        return total;
    }

    function getHoldingValues(address _user) public view returns(uint256[] memory){
        uint256[] memory HoldingValues;

        HoldingValues[0] = getLongHoldingValue(_user);
        HoldingValues[1] = getShortHoldingValue(_user);

        return HoldingValues;

    }
}

// for proxying purposes
contract FixedProductMarketMakerData {
    mapping(address => uint256) internal _balances;
    mapping(address => mapping(address => uint256)) internal _allowances;
    uint256 internal _totalSupply;
    bytes4 internal constant _INTERFACE_ID_ERC165 = 0x01ffc9a7;
    mapping(bytes4 => bool) internal _supportedInterfaces;
    event FPMMFundingAdded(
        address indexed funder,
        uint256[] amountsAdded,
        uint256 sharesMinted
    );
    event FPMMFundingRemoved(
        address indexed funder,
        uint256[] amountsRemoved,
        uint256 collateralRemovedFromFeePool,
        uint256 sharesBurnt
    );
    event FPMMBuy(
        address indexed buyer,
        uint256 investmentAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensBought
    );
    event FPMMSell(
        address indexed seller,
        uint256 returnAmount,
        uint256 feeAmount,
        uint256 indexed outcomeIndex,
        uint256 outcomeTokensSold
    );
    ConditionalTokens internal conditionalTokens;
    IERC20 internal collateralToken;
    bytes32[] internal conditionIds;
    uint256 internal fee;
    uint256 internal feePoolWeight;
    uint256[] internal outcomeSlotCounts;
    bytes32[][] internal collectionIds;
    uint256[] internal positionIds;
    mapping(address => uint256) internal withdrawnFees;
    uint256 internal totalWithdrawnFees;
}
