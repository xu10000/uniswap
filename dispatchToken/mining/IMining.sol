pragma solidity ^0.5.0;

/**
 * 共振
 */
interface IMining {
    // function bind(address developer, address usdtWallet) external returns (bool);
   
    // function transfer(uint256 amount, recipient address) external;
    function deposit(uint256 amount) external returns (bool);
    
    function withdraw(uint256[] calldata indexs) external returns (bool);
    
    function mining(uint256[] calldata indexs) external returns (bool);
    
    function orders(address account) external view returns (uint256[] memory, uint256[] memory);
    
    function currentCycleAndRemainHeight() external view returns (uint256, uint256);
    
    function miningAmountNow(address account) external view returns (uint256);

    function isBonus(uint256 day) external view returns(bool);

    function cut(uint256 day) external returns (bool);
    
    // function changeResonateContractInTest(uint256 resonateContract) external returns (bool);
    
    // function test() external returns (bool);
    
    function dailyMining(uint256 cycle) external view returns (uint256);
    
    function firstHeight() external view returns (uint256);

}
