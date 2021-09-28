pragma solidity ^0.5.0;

import "./IWallet.sol";

contract EthWallet is IWallet {

    address private _owner;
    address private _resonateContract;
    
    constructor () public EthWallet() {
        _owner = msg.sender;
    }
    
    function bind(address resonateContract) public returns (bool) {
        require(_owner == msg.sender, '_owner != msg.sender');
        require(_resonateContract == address(0), "_root not null");
        _resonateContract = resonateContract;
    }
    
    function transfer(uint256 amount, address payable recipient)  public payable returns (bool){
        require(msg.sender == _resonateContract, "msg.sender != _resonateContract");
        recipient.transfer(amount);
        return true;
    }
    
    function () payable external {
    }
}
