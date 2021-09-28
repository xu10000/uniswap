pragma solidity ^0.5.0;

/**
 * 共振
 */
interface IWallet {
   
    function bind(address developer) external returns (bool);
   
    function transfer(uint256 amount, address payable recipient) external payable returns (bool);
}
