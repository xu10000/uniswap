pragma solidity ^0.5.0;

/**
 * 共振
 */
interface IResonate {
    
    function peoplesToday() external returns (uint256);

    function deposit() external payable;

    function resonate() external returns (bool);

    function balanceOfRewardEth(address account) external view returns (uint256);

    function balanceOfEth(address account) external view returns (uint256);
    
    function cut() external returns (bool);
    
    function withdrawEth() external returns (bool);
    
    function withdrawRewardEth() external returns (uint256);
    
    function bind(address payable developer, address payable investor,  address payable buyBacker, address payable ethWallet, address payable easterEggWallet) external returns (bool);
   
    function lastDayOfAccount(address account) external view returns (uint256);
   
    function resonateEthDay(uint256 day) external view returns (uint256);
    
    function totalEth() external view returns (uint256);
    
    function firstHeight() external view returns (uint256);
    
    function preLuckEth(address account) external view returns (uint256);
    
    function luckEthDayOfReward(uint256 day) external view returns (uint256);
    
    function todayAndRemainHeight() external view returns (uint256, uint256);
    
    function openEasterEgg() external returns (bool);
        
    function lastHeight() external view returns (uint256);

    function getRate() external view returns (uint256);
    
    function getEthRate(uint256 day) external view returns (uint256);
    
    function isOver() external view returns (bool);

    function easterEggPeople() external view returns (address[] memory, bool[] memory, uint256[] memory);
    
    function preCutDay() external view returns(uint256);
    
    function dayOfEth(uint256 day) external view returns(uint256);
    
    function maxAmountAndRate() external view returns (uint256, uint256, uint256);
    
    function totalEasterEggBalance() external view returns (uint256);
    
    function getEggReward(address account) external view returns (uint256);
    // function test() external  view returns (uint256);
}
