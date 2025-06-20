// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract GasOptimizer {
    struct Transaction {
        address from;
        address to;
        uint256 value;
        uint256 gasUsed;
        uint256 timestamp;
    }
    
    mapping(address => Transaction[]) public userTransactions;
    mapping(address => uint256) public totalGasSaved;
    address public owner;
    uint256 public totalOptimizations;
    
    event GasOptimized(address indexed user, uint256 gasSaved, uint256 timestamp);
    event TransactionAnalyzed(address indexed user, uint256 gasUsed);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalOptimizations = 0;
    }
    
    function analyzeTransaction(address _to, uint256 _value, uint256 _gasUsed) external {
        Transaction memory newTx = Transaction({
            from: msg.sender,
            to: _to,
            value: _value,
            gasUsed: _gasUsed,
            timestamp: block.timestamp
        });
        
        userTransactions[msg.sender].push(newTx);
        emit TransactionAnalyzed(msg.sender, _gasUsed);
    }
    
    function optimizeGas(uint256 _potentialSavings) external {
        require(_potentialSavings > 0, "Savings must be greater than 0");
        
        totalGasSaved[msg.sender] += _potentialSavings;
        totalOptimizations++;
        
        emit GasOptimized(msg.sender, _potentialSavings, block.timestamp);
    }
    
    function getUserTransactionCount(address _user) external view returns (uint256) {
        return userTransactions[_user].length;
    }
    
    function getOptimizationStats() external view returns (uint256 totalSaved, uint256 optimizationCount) {
        totalSaved = totalGasSaved[msg.sender];
        optimizationCount = totalOptimizations;
    }
}
