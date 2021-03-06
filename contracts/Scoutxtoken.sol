// SPDX-License-Identifier: MIT



pragma solidity ^0.8.4;


import {ConditionalTokens} from "./ConditionalTokens.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";


contract ScoutX is ERC20, ERC20Burnable {
    uint256 constant ONE = 10**18;
    uint256 realamount;
    uint constant limit = 10000;
    address owner;
    address[] team;

    

    mapping (address => uint256) public realbalanceOf;
    constructor() ERC20("ScoutX", "SXT") {
        uint256 ownerinitial = 100000 * (10 ** 18);
        _mint(msg.sender, ownerinitial);
        realbalanceOf[msg.sender] = 100000;
        owner = msg.sender;

    }


    modifier onlyOwner {
        require(msg.sender == owner , "only owner can call this function");
        _;
    }
    

    function mint(address to, uint256 amount) external {



        bool teammember;

        for ( uint i = 0 ; i < team.length ; i++) {
            if(to == team[i]) {
                teammember = true;
                break;
            }
            else {
                teammember = false;
            }
        }



        if ((msg.sender != owner) && (teammember = false)) {
        require((realbalanceOf[msg.sender] + amount < limit) , "Only 10000 tokens per user");
        }

   

        
        realamount = amount * (10 ** 18);
        _mint(to, realamount);
        realbalanceOf[to] = realbalanceOf[to] + amount;
        
    }

    function mintme(uint256 amount) external {

        bool teammember;

        for ( uint i = 0 ; i < team.length ; i++) {
            if(msg.sender == team[i]) {
                teammember = true;
                break;
            }
            else {
                teammember = false;
            }
        }



        if ((msg.sender != owner) && (teammember = false)) {
        require((realbalanceOf[msg.sender] + amount < limit) , "Only 10000 tokens per user");
        }



        
        realamount = amount * (10 ** 18);
        _mint(msg.sender, realamount);
        realbalanceOf[msg.sender] = realbalanceOf[msg.sender] + amount;
        
    }


    function getMyBalance() public view returns(uint256){
        return realbalanceOf[msg.sender];
    }

    function getBalanceOf(address _user) public view returns(uint256){
        return realbalanceOf[_user];
    }

    function batchSetApprovalForAll(address[] calldata addresses, uint256 amount) public {
        for(uint i = 0; i < addresses.length; i++) {
            _approve(msg.sender , addresses[i] , amount);
        }
    }

    function AddToTeamList(address _address) public {
        team.push(_address);

    }
}