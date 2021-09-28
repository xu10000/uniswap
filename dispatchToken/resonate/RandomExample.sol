/**
 * @notice  Provable Random Datasource Example
 *
 *          This contract uses the random-datasource to securely generate
 *          off-chain random bytes.
 *
 *          The random datasource is currently only available on the
 *          ethereum main-net & public test-nets (Ropsten, Rinkeby & Kovan).
 *
 */
pragma solidity >= 0.5.0 < 0.6.0;

import "github.com/provable-things/ethereum-api/provableAPI.sol";
import "../math/SafeMath.sol";
import "./IResonate.sol";
import "../token/SimpleToken.sol";
import "./EthWallet.sol";

contract RandomExample is usingProvable, IResonate {

    // uint256 constant MAX_INT_FROM_BYTE = 256;
    uint256 constant NUM_RANDOM_BYTES_REQUESTED = 7;
    using SafeMath for uint256;
    
    struct EggObj {
        address account;
        uint256 amount;
        bool distribution;
    }
    
    struct DaysOfAmount {
        uint256 rate;
        uint256 resonateAmount;
        uint256 totalAmount;
    }
    
    struct PreLuck {
        uint256 amount;
        uint256 day;
    }
    
    event Withdraw(address indexed sender, address indexed recipient, uint256 indexed amount);
    event Cut(uint256 indexed amount);
        // event LogNewProvableQuery(string indexed description);
    event generatedRandomNumber(uint256 indexed randomNumber);
    
    mapping (address => uint256) private _depositEthBalances; // 用户充值eth数量
    mapping (address => uint256) private _ethRewardBalances; // 用户中奖的eth
    mapping (address => uint256) private _lastDay; //用户最后一次共振天数
    mapping (uint256 => uint256) private _dayOfEth; //每天参与共振的数量
    mapping (uint256 => uint256) private _resonateEthDay; // //每个天数共振eth的数量 
    mapping (uint256 => uint256) private _luckEthDay; //每个天数所有eth中奖人的充值总额
    mapping (uint256 => uint256) private _rewards; //每个天数抽奖池里的金额
    mapping (uint256 => uint256) private _peoples; //每个天数能参与抽奖的人
    mapping (uint256 => EggObj)  private _easterEggPeople; // 最后100参与共振的人

    mapping (address => PreLuck) private _preLuckEth; // 上次eth中奖充值的eth数量

    DaysOfAmount private _maxAmount; // 所有五天周期eth最高充值金额
    DaysOfAmount private _preAmount; // 上个五天的充值金额
    DaysOfAmount private _currentAmount; // 当前五天周期的充值总额
    uint256 MAXRANDOM = 100;
    uint256 private OUTRANGE = 999999999;
    uint256 private _rateDayIndex; // 第几个五天减
    uint256 private _oneDay; //共振周期，一天为 8640
    uint256 private _ethContract;
    uint256 private _scContract;
    uint256 private _totalEth;
    uint256 private _preCutDay;
    uint256 private _decimalValue;
    uint256 private _minEth;
    address payable private _developer;
    address payable private _investor;
    address payable private _buyBacker;
    address payable private _luckWallet;
    address payable private _easterEggWallet; //彩蛋的钱包
    address private _owner;
    uint256 private _firstHeight;
    uint256 private _lastHeight; //最后一次共振的位置
    uint256 private _totalEasterEggBalance; //彩蛋的总奖金
    uint256 private _easterEggPeopleIndex; //最后一个彩蛋人的位置
    uint256 private _easterEggPeopleNumber; //最后多少人平分彩蛋
    uint256 private _rateDays; // 5 * 8640 = 43200 共振率5天一变化

    constructor(uint256 scContract)
        public
    {
        provable_setProof(proofType_Ledger);
        // _oneDay = 30;
        _oneDay = 8640;
        _scContract = scContract; //for rinkeby testnet
        _owner = msg.sender;
        _decimalValue = 1000000000000000000;
        _minEth = 1;
        _easterEggPeopleNumber = 100;
        // _rateDays = 60; // 5 * 8640 = 43200 5天
        _rateDays = 43200;
    }

    function _deposit() private {
        require(msg.value >= _decimalValue.mul(_minEth), "msg.value less than _decimalValue.mul(_minEth)");
        _isFirstDeposit();
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        uint256 lastDay  = _lastDay[msg.sender];

        require(lastDay < today, "only resonate once a day");
        require(isOver() == false, "resonate already over");
        
        _totalEth = _totalEth.add(msg.value);
        uint256 balance = _depositEthBalances[msg.sender].add(msg.value);
        _dayOfEth[today] = _dayOfEth[today].add(balance);
        // 更新五天一周期的金额
        _updateDaysAmount(balance);
        // 如果昨天没人中奖，则奖金累计到今天
        _updateReward();
        //  20%中奖
        uint256 random = _random(100);
        uint256 rate =  getRate();
        // // 中奖发放sc
        if (random <= rate) {
            // 更新当前5天的中签金额
            _currentAmount.resonateAmount = _currentAmount.resonateAmount.add(balance);
            _depositEthBalances[msg.sender] = 0;
            // SimpleToken sc = SimpleToken(_scContract);
            // sc.transfer(msg.sender, balance.mul(200));
            _resonateEthDay[today] = _resonateEthDay[today].add(balance);
            // 10% for rewards
            _rewards[today] = _rewards[today].add(balance.div(10));
            // 最后100个共振人
            _easterEggPeopleIndex = _easterEggPeopleIndex.add(1).mod(_easterEggPeopleNumber);
            _easterEggPeople[_easterEggPeopleIndex].account = msg.sender;
            _easterEggPeople[_easterEggPeopleIndex].amount = balance;
        } else {
            // 没有中奖则记录充值金额
            _peoples[today] = _peoples[today].add(1);
            _depositEthBalances[msg.sender] = _depositEthBalances[msg.sender].add(msg.value); //增加充值总额
            _luckRraw(today, balance);
            
        }
        
        _lastDay[msg.sender] = today;
        _lastHeight = block.number;
    }

    function __callback(
        bytes32 _queryId,
        string memory _result,
        bytes memory _proof
    )
        public
    {
        require(msg.sender == provable_cbAddress());

        if (
            provable_randomDS_proofVerify__returnCode(
                _queryId,
                _result,
                _proof
            ) != 0
        ) {
            /**
             * @notice  The proof verification has failed! Handle this case
             *          however you see fit.
             */
        } else {
            /**
             *
             * @notice  The proof verifiction has passed!
             *
             *          Let's convert the random bytes received from the query
             *          to a `uint256`.
             *
             *          To do so, We define the variable `ceiling`, where
             *          `ceiling - 1` is the highest `uint256` we want to get.
             *          The variable `ceiling` should never be greater than:
             *          `(MAX_INT_FROM_BYTE ^ NUM_RANDOM_BYTES_REQUESTED) - 1`.
             *
             *          By hashing the random bytes and casting them to a
             *          `uint256` we can then modulo that number by our ceiling
             *          in order to get a random number within the desired
             *          range of [0, ceiling - 1].
             *
             */
            // uint256 ceiling = (MAX_INT_FROM_BYTE ** NUM_RANDOM_BYTES_REQUESTED) - 1;
            uint256 ceiling = 100;
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(_result))) % ceiling;
            emit generatedRandomNumber(randomNumber);
            _deposit();
        }
    }


    function easterEggPeople() public view returns (address[] memory, bool[] memory,uint256[] memory) {
         address[] memory accounts = new address[](_easterEggPeopleNumber);
         bool[] memory distributions = new bool[](_easterEggPeopleNumber);
         uint256 [] memory amounts = new uint256[](_easterEggPeopleNumber);
         for (uint256 i = 0; i < _easterEggPeopleNumber; i++) {
             accounts[i] = _easterEggPeople[i].account;
             distributions[i] =  _easterEggPeople[i].distribution;
             amounts[i] =  _easterEggPeople[i].amount;
         }
         return (accounts, distributions, amounts);
    }
    
    function firstHeight() public view returns (uint256) {
        return _firstHeight;
    }
    /**
     * eth of draw
     **/
    function balanceOfRewardEth(address account) public view returns (uint256) {
        // 如果今天之前中奖
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        uint256 lastDay  = _lastDay[account];
        if(today > lastDay) {
            uint256 depositEth = _preLuckEth[account].amount;
            // 有中奖
            if(depositEth > 0) {
                if (_luckEthDay[lastDay] > 0) {
                    uint256 reward = _rewards[lastDay].mul(depositEth).div(_luckEthDay[lastDay]);
                    return _ethRewardBalances[account].add(reward);
                }
            }
        }
        
        return _ethRewardBalances[account];
    }
    
    function luckEthDayOfReward(uint256 day) public view returns (uint256) {
        return _luckEthDay[day];
    }
    
    function preLuckEth(address account) public view returns (uint256) {
        return _preLuckEth[account].amount;
    }
    
    
    function balanceOfEth(address account) public view returns (uint256) {
        return _depositEthBalances[account];
    }
    
    function _random(uint256 max) private view returns (uint256) {
        
        uint256 random = uint256(keccak256(abi.encodePacked(
            (block.timestamp).add
            (block.difficulty).add
            ((uint256(keccak256(abi.encodePacked(block.coinbase)))) / (now)).add
            (block.gaslimit).add
            ((uint256(keccak256(abi.encodePacked(msg.sender)))) / (now)).add
            (block.number)
        )))% max;
        return random.add(1);
        
    }
    /** 
     * 统计今天之前的eth中奖额度
    **/
    function _setPreEth(address sender) private {
        // 如果今天之前中奖
        uint256 depositEth = _preLuckEth[sender].amount;
        uint256 luckyDay = _preLuckEth[sender].day;

        if(depositEth > 0) {
            _preLuckEth[sender].amount = 0;
            _preLuckEth[sender].day = 0;
            // 10% for reward
            if (_luckEthDay[luckyDay] > 0) {
                uint256 reward = _rewards[luckyDay].mul(depositEth).div(_luckEthDay[luckyDay]);
                _ethRewardBalances[sender] = _ethRewardBalances[sender].add(reward);
            }
        }
    }
    
    function getEthRate(uint256 day) public view returns (uint256){
        //某天充值总额*10%/某天未中签总额
        uint256 luckNumber = _dayOfEth[day].sub(_resonateEthDay[day]);
        if(luckNumber == 0) {
            return 0;
        }
        uint256 rate = _dayOfEth[day].div(10).div(luckNumber);
        if(rate > 100) {
            return 100;
        }
        return rate;
    }
    /** 
     * 共振不成功的用户参与eth抽奖
    **/
    function _luckRraw(uint256 today, uint256 amount) private {
            // 抽奖eth中奖概率getEthRate
            uint256 random = _random(100);
            uint256 rate = getEthRate(today.sub(1));
            // random
            if(random <= rate) {
               // 如果之前有中奖的还没领取，则登记
               _setPreEth(msg.sender);
               _preLuckEth[msg.sender].amount = amount;
               _preLuckEth[msg.sender].day = today;
               _luckEthDay[today] = _luckEthDay[today].add(amount);
            }
    }
    
    function _withdrawEth(uint256 amount, address payable recipient) private {
        require(amount > 0, "withdraw eth balance must bigger that 0");
        _totalEth = _totalEth.sub(amount);
        emit Withdraw(address(this), recipient, amount);
        // SimpleToken eth = SimpleToken(_ethContract);
        recipient.transfer(amount);
    }
    
    function withdrawEth() public returns (bool) {
        uint256 amount = _depositEthBalances[msg.sender];
        _depositEthBalances[msg.sender] = 0;
        _withdrawEth(amount, msg.sender);
    }
    
    function _withdrawRewardEth(uint256 amount, address payable sender) private returns (bool){
        EthWallet luck = EthWallet(_luckWallet);
        luck.transfer(amount, sender);
        emit Withdraw(_luckWallet, sender, amount);
        return true;
    }
    
    function withdrawRewardEth() public returns (uint256){
        // 只有抽成后才能提现
        uint256 lastDay = _lastDay[msg.sender];
        require(_preCutDay >= lastDay, "pls cut before call withdrawEth");
        
        // 统计今天之前的抽奖金额
        // if(lastDay <= yesterday) {
            // 统计用户今天之前抽奖的eth总数
            _setPreEth(msg.sender);
        // }
        
        uint256 amount = _ethRewardBalances[msg.sender];
        
        if(amount > 0) {
            _ethRewardBalances[msg.sender] = 0;
            _withdrawRewardEth(amount, msg.sender);
        }
        return amount;
    }
    

    function resonate() public returns (bool) {
        uint256 amount = _depositEthBalances[msg.sender];
        require(amount >= _decimalValue.mul(_minEth), "amount less than _decimalValue.mul(_minEth)");
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        uint256 lastDay  = _lastDay[msg.sender];
        
        // isResonateTody(today)
        require(lastDay < today, "only resonate once a day");
        
        // require(block.number.sub(_lastHeight) <= _oneDay, "resonate already over");
        require(isOver() == false, "resonate already over");

        _dayOfEth[today] = _dayOfEth[today].add(amount);
        // 更新五天一周期的金额
        _updateDaysAmount(amount);
        // 如果昨天没人中奖，则奖金累计到今天
        _updateReward();
        //  20%中奖
        uint256 random = _random(100);
        // 中奖发放sc
        if (random <= 50) {
            _depositEthBalances[msg.sender] = 0;
            SimpleToken sc = SimpleToken(_scContract);
            sc.transfer(msg.sender, amount.mul(200));
            _resonateEthDay[today] = _resonateEthDay[today].add(amount);
            // 10% for rewards
            _rewards[today] = _rewards[today].add(amount.div(10));
            // 最后100个共振人
        } else {
            // 没有中奖则记录充值金额
            _peoples[today] = _peoples[today].add(1);
            _luckRraw(today, amount);
            _easterEggPeopleIndex = _easterEggPeopleIndex.add(1).mod(_easterEggPeopleNumber);
            _easterEggPeople[_easterEggPeopleIndex].account = msg.sender;
            _easterEggPeople[_easterEggPeopleIndex].amount = amount;
        }
        
        _lastDay[msg.sender] = today;
        _lastHeight = block.number;
        return true;
    } 
    
    function _updateReward() private {
        uint256 yesterday = block.number.sub(_firstHeight).div(_oneDay);
        // 昨天没人中奖，奖励累计到今天
        if(_luckEthDay[yesterday] == 0) {
            _rewards[yesterday.add(1)] = _rewards[yesterday.add(1)].add(_rewards[yesterday]);
            _rewards[yesterday] = 0;
        }
    }
    
    function _isFirstDeposit() private {
        // 如果第一次充值，记录高度
        if(_firstHeight == 0) {
            _firstHeight = block.number;
        }
    }
    
    function lastDayOfAccount(address account) public view returns (uint256) {
         return _lastDay[account]; 
    }
    
    function resonateEthDay(uint256 day) public view returns (uint256) {
         return _resonateEthDay[day]; 
    }
    
    function getRate() public view returns (uint256) {
        uint256 cycle = block.number.sub(_firstHeight).div(_rateDays).add(1);
        // 前4个周期100% 
        if (cycle <= 4) {
            return 100;
        }
        
        if(cycle == 5) {
            return 20;
        }
        // 倒数第二周期大于最大周期的共振金额，则继续按20计算
        if(_preAmount.totalAmount >= _maxAmount.totalAmount) {
            return 20;
        }
        // （之前大周期最大参与总量*该周期中签率）/本周期参与总量
        uint256 rate = _maxAmount.totalAmount.mul(_maxAmount.rate).div(_preAmount.totalAmount);
        if(rate > 90) {
            return 90;
        }
        
        return rate;
    }
    
    function _updateDaysAmount(uint256 amount) private returns (bool) {
        
        uint256 cycle = block.number.sub(_firstHeight).div(_rateDays).add(1);
        // 新五天的第一笔充值
        if(_rateDayIndex < cycle) { 
            _rateDayIndex = cycle; 
            _preAmount = _currentAmount;
            _currentAmount.totalAmount = amount; 
            _currentAmount.resonateAmount = 0;
            // 更新五天周期最高的共振金额 
            if(_maxAmount.resonateAmount < _preAmount.resonateAmount) {
                _maxAmount = _preAmount; 
            }
            _currentAmount.rate = getRate();
        } else {
            _currentAmount.totalAmount = _currentAmount.totalAmount.add(amount);
        }
        
        return true;
    }
    
    function isOver() public view returns (bool) {
        if(_lastHeight == 0) {
            return false;
        }
        
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        uint256 lastDay = _lastHeight.sub(_firstHeight).div(_oneDay).add(1);

        if(today.sub(lastDay) < 2) {
            return false;
        }
        return true;
    }
    
    function deposit() public payable{

        uint256 QUERY_EXECUTION_DELAY = 0;
        uint256 GAS_FOR_CALLBACK = 200000;
        provable_newRandomDSQuery(
            QUERY_EXECUTION_DELAY,
            NUM_RANDOM_BYTES_REQUESTED,
            GAS_FOR_CALLBACK
        );
    }
    
    function openEasterEgg() public returns (bool) {
        // 超过一天没人充值，则领取彩蛋
        require(isOver(), "resonate not over");
        uint256 lastDay = _lastHeight.sub(_firstHeight).div(_oneDay).add(1);
        require(lastDay == _preCutDay, "pls call after cut");
        uint256 senderBalance = 0;
        uint256 total = 0;
        
        for(uint256 i = 0; i < _easterEggPeopleNumber; i++) {
            if(_easterEggPeople[i].account == msg.sender) {
                require(_easterEggPeople[i].distribution == false, "already open egg");
                senderBalance = senderBalance.add(_easterEggPeople[i].amount);
                _easterEggPeople[i].distribution = true;
            }
            total = total.add(_easterEggPeople[i].amount);
        }
        
        require(senderBalance != 0, 'msg.sender not in _easterEggPeople');
        // 游戏结束，抽成后可领取
        uint256 balance = senderBalance.mul(_totalEasterEggBalance).div(total);
        EthWallet egg = EthWallet(_easterEggWallet);
        egg.transfer(balance, msg.sender);
        emit Withdraw(_easterEggWallet, msg.sender, balance);
        return true;
        
    }
    
    function lastHeight() public view returns (uint256) {
        return _lastHeight;
    }
    /**
     * 绑定项目方冷钱包和eth钱包合约
    **/
    function bind(address payable developer, address payable investor, address payable buyBacker, address payable luckWallet, address payable easterEggWallet) public returns (bool) {
        require(_owner == msg.sender, '_owner != msg.sender');
        _developer = developer;
        _investor = investor;
        _buyBacker = buyBacker;
        _luckWallet = luckWallet;
        _easterEggWallet = easterEggWallet;
    }
    /**
     * 抽成
    **/
    function cut() public returns (bool){

        require(_developer != address(0), "_developer not bind");
        require(_luckWallet != address(0), "_luckWallet not bind");
        require(_easterEggWallet != address(0), "_easterEggWallet not bind");
        uint256 yesterday = block.number.sub(_firstHeight).div(_oneDay);
        require(_preCutDay <= yesterday, "already cut");
        _preCutDay = _preCutDay.add(1);
        require(_dayOfEth[_preCutDay] != 0, "resonate already over, _dayOfEth[_preCutDay] = 0");
        // 10%分配到抽奖池，5%分配到彩蛋池，5%分配给开发团队（指定地址），80%回购销毁和生态建设（指定地址）
        if (_resonateEthDay[_preCutDay] > 100) {
            uint256 developerBalance = _resonateEthDay[_preCutDay].mul(5).div(100);
            uint256 investorBalance = _resonateEthDay[_preCutDay].mul(30).div(100);
            uint256 buyBackBalance = _resonateEthDay[_preCutDay].mul(50).div(100);
            uint256 easterEggBalance = _resonateEthDay[_preCutDay].mul(5).div(100);
            uint256 luckWalletBalance = _resonateEthDay[_preCutDay].mul(10).div(100);
            _totalEasterEggBalance = _totalEasterEggBalance.add(easterEggBalance);
            _withdrawEth(developerBalance, _developer);
            _withdrawEth(investorBalance, _investor);
            _withdrawEth(buyBackBalance, _buyBacker);
            _withdrawEth(luckWalletBalance, _luckWallet);
            _withdrawEth(easterEggBalance, _easterEggWallet);
            emit Cut(_resonateEthDay[_preCutDay]);
        }
            
        return true;
    }
    
    function dayOfEth(uint256 day) public view  returns(uint256) {
        return _dayOfEth[day];
    }
    
    function preCutDay() public view returns(uint256) {
        return _preCutDay;
    }
    
    function peoplesToday() public returns (uint256) {
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        return _peoples[today];
    }
    
    function totalEth() public view returns (uint256) {
        return _totalEth;
    }

    function todayAndRemainHeight() public view returns (uint256, uint256) {
        if(_firstHeight == 0) {
            return (0, 0);
        }
        uint256 today = block.number.sub(_firstHeight).div(_oneDay).add(1);
        // 当前周期还剩几个高度结束
        uint256 remainHeight = _oneDay.sub(block.number.sub(_firstHeight).mod(_oneDay));
        return (today, remainHeight.sub(1));
    }
}