pragma solidity ^0.5.0;

import "../token/SimpleToken.sol";
import "../math/SafeMath.sol";
import "./IMining.sol";
import "../resonate/Resonate.sol";

contract Mining is IMining {
    
    using SafeMath for uint256;
    
    struct Order {
        uint256 height;
        uint256 amount;
        bool mark;
    }
    
    event Cut(uint256 indexed inviteAmount, uint256 indexed developerAmount);
    event MiningOrder(address indexed miner, uint256 indexed amount, uint256 indexed unlockHeight);

    mapping (address => Order[]) private _userOrders;
    mapping (uint256 => uint256) private _dailyMining; // 每天参与挖矿的数量
    mapping (uint256 => bool) private _isBonus;  // 某天的抽成是否下发

    uint256 private _firstHeight;
    uint256 private _decimalValue;
    uint256 private _minSc;
    uint256 private _cycleNumber;
    uint256 private _oneDay;
    uint256 private _scContract;
    uint256 private _resonateContract;
    uint256 private OUTRANGE = 999999999;
    // address private _owner;
    address private _developerAddress;
    address private _inviteAddress;
    
    // address private _owner;
    constructor (address developerAddress, address inviteAddress, uint256 scContract, uint256 resonateContract) public {
        _developerAddress = developerAddress;
        _inviteAddress = inviteAddress;
        // _owner = owner;
        _decimalValue = 1000000000000000000;
        _minSc = 100;
        // _oneDay = 180; //for test, mainnet 8640
        _oneDay = 8640;
        // _cycleNumber = 360; // four minutes for test
        _cycleNumber = 259200; //一个月一个周期
        _scContract = scContract; // test address
        _resonateContract = resonateContract;
    }
    
    // function changeResonateContractInTest(uint256 resonateContract) public returns (bool){
    //     require(msg.sender == _owner, "msg.sender != _owner");
    //     _resonateContract = resonateContract;
    //     return true;
    // }
    
    // function test() public returns (bool){
    //     // 检查共振是否结束
    //     Resonate rs = Resonate(_resonateContract);
    //     require(rs.isOver() == false, "activity already completed");
    //     return true;
    // }
    
    function _isFirstDeposit() private {
        // 如果第一次充值，记录高度
        if(_firstHeight == 0) {
            _firstHeight = block.number;
        }
    }
    
    function _getUnlockHeight() private view returns (uint256){
        uint256 currentCycle = block.number.sub(_firstHeight).div(_cycleNumber).add(1);
        // 计算每个周期的收益时间
        if (currentCycle <= 9) {
            return currentCycle.add(6).mul(_oneDay).add(block.number);  //min 7
        } else {
            return _oneDay.mul(15).add(block.number); // max 15 
        }
    }
    
    function cut(uint256 day) public returns (bool) {
        require(_firstHeight != 0, "_firstHeight == 0");
        uint256 yesterday = block.number.sub(_firstHeight).div(_oneDay);
        require(yesterday >= day, "yesterday is small than input day");
        require(_isBonus[day] == false, "the day is already cut");
        SimpleToken sc = SimpleToken(_scContract);
        _isBonus[day] = true;
        
        // require(_dailyMining[day] >= 100, "_dailyMining[day] is less than 100 on this day");
        if(_dailyMining[day] >= 100) {
            uint256 inviteAmount = _dailyMining[day].mul(14).div(100);
            uint256 developerAmount = _dailyMining[day].mul(3).div(100);
            
            emit Cut(inviteAmount, developerAmount);
            sc.transfer(_inviteAddress, inviteAmount);
            sc.transfer(_developerAddress, developerAmount);
        }
        
        return true;
    }
    
    function isBonus(uint256 day) public view returns(bool) {
        return _isBonus[day];
    }
    
    function miningAmountNow(address account) public view returns (uint256) {
        uint256 total = 0;
        for(uint256 i = 0; i < _userOrders[account].length; i++) {
            if(_userOrders[account][i].height > block.number) {
                total = total.add(_userOrders[account][i].amount);
            }
        }
        return total;
    }
    
    function deposit(uint256 amount) public returns (bool) {
        require(amount >= _decimalValue.mul(_minSc), "amount less than _decimalValue.mul(_minSc)");
        require(_userOrders[msg.sender].length < 20, "order length is bigger than 20"); // 最大20，19后加1
        _isFirstDeposit();
        // 检查共振是否结束
        Resonate rs = Resonate(_resonateContract);
        require(rs.isOver() == false, "activity already completed");
        // 充值sc
        SimpleToken sc = SimpleToken(_scContract);
        sc.transferFrom(msg.sender, address(this), amount);
        // 计算解锁高度
        uint256 unlockHeight = _getUnlockHeight(); 

        _userOrders[msg.sender].push(Order({
            height: unlockHeight,
            amount: amount,
            mark: false
        }));
        // 计算今天挖矿的数量
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        _dailyMining[today] = amount.add(_dailyMining[today]);
        // 广播
        emit MiningOrder(msg.sender, amount, unlockHeight);
        return true;
    }
    
    /**
    * 提取挖矿奖励
    **/
    function withdraw(uint256[] memory indexs) public returns (bool) {
        require(indexs.length <= 20, "indexs.length > 20");
        uint256 amount = 0;
        for(uint256 i = 0; i < indexs.length; i++) {
            uint256 index = indexs[i];
            require(index < _userOrders[msg.sender].length, "index is out of _userOrders[msg.sender] range");
            require(_userOrders[msg.sender][index].mark == false, "_userOrders[msg.sender][index].mark == true, maybe value is duplicate");
            if(block.number > _userOrders[msg.sender][index].height) {
                // mark element
                _userOrders[msg.sender][index].mark = true;
                // add value
                amount = amount.add(_userOrders[msg.sender][index].amount);
            }
        }
        // leave gap
        for(uint256 i = 0; i < _userOrders[msg.sender].length;) {
            if(_userOrders[msg.sender][i].mark) {
                for (uint j = i; j < _userOrders[msg.sender].length.sub(1); j++){
                    _userOrders[msg.sender][j] = _userOrders[msg.sender][j+1];
                }
                delete _userOrders[msg.sender][_userOrders[msg.sender].length.sub(1)];
                _userOrders[msg.sender].length = _userOrders[msg.sender].length.sub(1) ;
            } else {
                 i++;
            }
        }
        
        require(amount > 0, "amount = 0");
        amount = amount.mul(110).div(100);
        SimpleToken sc = SimpleToken(_scContract);
        sc.transfer(msg.sender, amount);
        return true;
        
    }
    /**
     * 再次挖矿
     **/
     function mining(uint256[] memory indexs) public returns (bool) {
        // 检查共振是否结束
        Resonate rs = Resonate(_resonateContract);
        require(rs.isOver() == false, "activity already completed");
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        require(indexs.length <= 20, "indexs.length > 20");
        uint256 unlockHeight = _getUnlockHeight();
        uint256 total = 0;
        //  uint256 total = 0;
         for(uint256 i = 0; i < indexs.length; i++) {
            uint256 index = indexs[i];
            require(index < _userOrders[msg.sender].length, "index is out of _userOrders[msg.sender] range" );
            if(block.number > _userOrders[msg.sender][index].height) {
                _userOrders[msg.sender][index].height = unlockHeight;
                uint256 balance = _userOrders[msg.sender][index].amount.mul(110).div(100);
                _userOrders[msg.sender][index].amount = balance;
                total = total.add(balance);
                // 计算今天挖矿增发的数量
                _dailyMining[today] = _dailyMining[today].add(balance);
            }
        }
        
        emit MiningOrder(msg.sender, total, unlockHeight);

        return true;
     }
     
     function orders(address account) public view returns (uint256[] memory, uint256[] memory) {
         uint256[] memory unlockHeights = new uint256[](_userOrders[account].length);
         uint256[] memory amounts = new uint256[](_userOrders[account].length);
         for (uint256 i = 0; i < _userOrders[account].length; i++) {
             unlockHeights[i] = _userOrders[account][i].height;
             amounts[i] =  _userOrders[account][i].amount;
         }
         return (unlockHeights, amounts);
     }
     
    function currentCycleAndRemainHeight() public view returns (uint256, uint256) {
        if(_firstHeight == 0) {
            return (0, 0);
        }
        
        uint256 currentCycle = block.number.sub(_firstHeight).div(_cycleNumber).add(1);
        // 当前周期还剩几个高度结束
        uint256 remainHeight = _cycleNumber.sub(block.number.sub(_firstHeight).mod(_cycleNumber));
        if(remainHeight == 0) {
            return (currentCycle, _cycleNumber.sub(1));
        }
        return (currentCycle, remainHeight.sub(1));
    }
    
    function dailyMining(uint256 cycle) public view returns (uint256){
        return _dailyMining[cycle];
    }
    
    function firstHeight() public view returns (uint256) {
        return _firstHeight;
    }
    
}
