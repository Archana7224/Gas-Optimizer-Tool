// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract GasOptimizer {
    struct Transaction {
        address from;
        address to;
        uint256 value;
        uint256 gasUsed;
        uint256 gasPrice;
        uint256 timestamp;
        string txType; // "transfer", "contract_call", "deployment"
    }
    
    struct OptimizationRecommendation {
        uint256 averageGasUsed;
        uint256 recommendedGasLimit;
        uint256 potentialSavings;
        uint256 transactionCount;
        bool hasRecommendation;
    }
    
    struct GasReport {
        uint256 totalTransactions;
        uint256 totalGasConsumed;
        uint256 totalGasCost;
        uint256 averageGasPrice;
        uint256 mostExpensiveTx;
        uint256 cheapestTx;
    }
    
    mapping(address => Transaction[]) public userTransactions;
    mapping(address => uint256) public totalGasSaved;
    mapping(address => uint256) public gasBudget;
    mapping(string => uint256) public gasBaselines; // Gas baselines for different tx types
    address public owner;
    uint256 public totalOptimizations;
    uint256 public platformFee = 1000; // 0.1% in basis points
    
    event GasOptimized(address indexed user, uint256 gasSaved, uint256 timestamp);
    event TransactionAnalyzed(address indexed user, uint256 gasUsed);
    event RecommendationGenerated(address indexed user, uint256 potentialSavings);
    event BudgetSet(address indexed user, uint256 budget);
    event BudgetExceeded(address indexed user, uint256 spent, uint256 budget);
    event BaselineUpdated(string txType, uint256 newBaseline);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        totalOptimizations = 0;
        
        // Set initial gas baselines
        gasBaselines["transfer"] = 21000;
        gasBaselines["contract_call"] = 50000;
        gasBaselines["deployment"] = 200000;
    }
    
    /**
     * @dev Analyzes and records a transaction with enhanced details
     */
    function analyzeTransaction(
        address _to, 
        uint256 _value, 
        uint256 _gasUsed, 
        uint256 _gasPrice,
        string memory _txType
    ) external validAddress(_to) {
        Transaction memory newTx = Transaction({
            from: msg.sender,
            to: _to,
            value: _value,
            gasUsed: _gasUsed,
            gasPrice: _gasPrice,
            timestamp: block.timestamp,
            txType: _txType
        });
        
        userTransactions[msg.sender].push(newTx);
        
        // Check budget if set
        if (gasBudget[msg.sender] > 0) {
            uint256 txCost = _gasUsed * _gasPrice;
            uint256 totalSpent = getTotalGasCost(msg.sender);
            if (totalSpent > gasBudget[msg.sender]) {
                emit BudgetExceeded(msg.sender, totalSpent, gasBudget[msg.sender]);
            }
        }
        
        emit TransactionAnalyzed(msg.sender, _gasUsed);
    }
    
    /**
     * @dev Records gas optimization with validation
     */
    function optimizeGas(uint256 _potentialSavings) external {
        require(_potentialSavings > 0, "Savings must be greater than 0");
        
        totalGasSaved[msg.sender] += _potentialSavings;
        totalOptimizations++;
        
        emit GasOptimized(msg.sender, _potentialSavings, block.timestamp);
    }
    
    /**
     * @dev Sets a gas budget for the user
     */
    function setGasBudget(uint256 _budget) external {
        require(_budget > 0, "Budget must be greater than 0");
        gasBudget[msg.sender] = _budget;
        emit BudgetSet(msg.sender, _budget);
    }
    
    /**
     * @dev Batch analyzes multiple transactions for efficiency
     */
    function batchAnalyzeTransactions(
        address[] memory _to,
        uint256[] memory _values,
        uint256[] memory _gasUsed,
        uint256[] memory _gasPrices,
        string[] memory _txTypes
    ) external {
        require(_to.length == _values.length && 
                _values.length == _gasUsed.length && 
                _gasUsed.length == _gasPrices.length &&
                _gasPrices.length == _txTypes.length, "Array lengths must match");
        
        for (uint256 i = 0; i < _to.length; i++) {
            Transaction memory newTx = Transaction({
                from: msg.sender,
                to: _to[i],
                value: _values[i],
                gasUsed: _gasUsed[i],
                gasPrice: _gasPrices[i],
                timestamp: block.timestamp,
                txType: _txTypes[i]
            });
            
            userTransactions[msg.sender].push(newTx);
        }
    }
    
    /**
     * @dev Calculates total gas cost for a user
     */
    function getTotalGasCost(address _user) public view returns (uint256 totalCost) {
        Transaction[] memory transactions = userTransactions[_user];
        for (uint256 i = 0; i < transactions.length; i++) {
            totalCost += transactions[i].gasUsed * transactions[i].gasPrice;
        }
    }
    
    /**
     * @dev Generates comprehensive gas report for a user
     */
    function generateGasReport(address _user) external view returns (GasReport memory report) {
        Transaction[] memory transactions = userTransactions[_user];
        uint256 txCount = transactions.length;
        
        if (txCount == 0) {
            return GasReport(0, 0, 0, 0, 0, type(uint256).max);
        }
        
        uint256 totalGas = 0;
        uint256 totalCost = 0;
        uint256 totalGasPrice = 0;
        uint256 mostExpensive = 0;
        uint256 cheapest = type(uint256).max;
        
        for (uint256 i = 0; i < txCount; i++) {
            uint256 txCost = transactions[i].gasUsed * transactions[i].gasPrice;
            totalGas += transactions[i].gasUsed;
            totalCost += txCost;
            totalGasPrice += transactions[i].gasPrice;
            
            if (txCost > mostExpensive) mostExpensive = txCost;
            if (txCost < cheapest) cheapest = txCost;
        }
        
        return GasReport({
            totalTransactions: txCount,
            totalGasConsumed: totalGas,
            totalGasCost: totalCost,
            averageGasPrice: totalGasPrice / txCount,
            mostExpensiveTx: mostExpensive,
            cheapestTx: cheapest
        });
    }
    
    /**
     * @dev Compares user's gas usage against baselines
     */
    function compareAgainstBaseline(address _user, string memory _txType) 
        external view returns (uint256 averageGas, uint256 baseline, bool isOptimal) {
        Transaction[] memory transactions = userTransactions[_user];
        uint256 relevantTxCount = 0;
        uint256 totalGasForType = 0;
        
        for (uint256 i = 0; i < transactions.length; i++) {
            if (keccak256(bytes(transactions[i].txType)) == keccak256(bytes(_txType))) {
                totalGasForType += transactions[i].gasUsed;
                relevantTxCount++;
            }
        }
        
        if (relevantTxCount == 0) {
            return (0, gasBaselines[_txType], false);
        }
        
        averageGas = totalGasForType / relevantTxCount;
        baseline = gasBaselines[_txType];
        isOptimal = averageGas <= baseline * 110 / 100; // Within 10% of baseline
    }
    
    /**
     * @dev Finds transactions within a time range
     */
    function getTransactionsByTimeRange(
        address _user, 
        uint256 _startTime, 
        uint256 _endTime
    ) external view returns (Transaction[] memory filteredTxs) {
        Transaction[] memory allTxs = userTransactions[_user];
        uint256 count = 0;
        
        // First pass: count matching transactions
        for (uint256 i = 0; i < allTxs.length; i++) {
            if (allTxs[i].timestamp >= _startTime && allTxs[i].timestamp <= _endTime) {
                count++;
            }
        }
        
        // Second pass: collect matching transactions
        filteredTxs = new Transaction[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allTxs.length; i++) {
            if (allTxs[i].timestamp >= _startTime && allTxs[i].timestamp <= _endTime) {
                filteredTxs[index] = allTxs[i];
                index++;
            }
        }
    }
    
    /**
     * @dev Calculates gas efficiency score (0-100)
     */
    function calculateEfficiencyScore(address _user) external view returns (uint256 score) {
        Transaction[] memory transactions = userTransactions[_user];
        if (transactions.length == 0) return 0;
        
        uint256 totalScore = 0;
        uint256 scoredTransactions = 0;
        
        for (uint256 i = 0; i < transactions.length; i++) {
            uint256 baseline = gasBaselines[transactions[i].txType];
            if (baseline > 0) {
                uint256 efficiency = (baseline * 100) / transactions[i].gasUsed;
                if (efficiency > 100) efficiency = 100; // Cap at 100%
                totalScore += efficiency;
                scoredTransactions++;
            }
        }
        
        return scoredTransactions > 0 ? totalScore / scoredTransactions : 0;
    }
    
    /**
     * @dev Estimates potential savings if all transactions were optimized
     */
    function estimateMaxPotentialSavings(address _user) external view returns (uint256 savings) {
        Transaction[] memory transactions = userTransactions[_user];
        
        for (uint256 i = 0; i < transactions.length; i++) {
            uint256 baseline = gasBaselines[transactions[i].txType];
            if (transactions[i].gasUsed > baseline) {
                uint256 excessGas = transactions[i].gasUsed - baseline;
                savings += excessGas * transactions[i].gasPrice;
            }
        }
    }
    
    // Owner functions
    function updateGasBaseline(string memory _txType, uint256 _newBaseline) external onlyOwner {
        gasBaselines[_txType] = _newBaseline;
        emit BaselineUpdated(_txType, _newBaseline);
    }
    
    function updatePlatformFee(uint256 _newFee) external onlyOwner {
        require(_newFee <= 10000, "Fee cannot exceed 100%");
        platformFee = _newFee;
    }
    
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // View functions from original contract
    function getUserTransactionCount(address _user) external view returns (uint256) {
        return userTransactions[_user].length;
    }
    
    function getOptimizationStats() external view returns (uint256 totalSaved, uint256 optimizationCount) {
        totalSaved = totalGasSaved[msg.sender];
        optimizationCount = totalOptimizations;
    }
    
    function generateOptimizationRecommendation(address _user) external view returns (OptimizationRecommendation memory recommendation) {
        Transaction[] memory transactions = userTransactions[_user];
        uint256 txCount = transactions.length;
        
        if (txCount == 0) {
            return OptimizationRecommendation({
                averageGasUsed: 0,
                recommendedGasLimit: 0,
                potentialSavings: 0,
                transactionCount: 0,
                hasRecommendation: false
            });
        }
        
        uint256 totalGasUsed = 0;
        uint256 maxGasUsed = 0;
        uint256 minGasUsed = type(uint256).max;
        
        for (uint256 i = 0; i < txCount; i++) {
            uint256 gasUsed = transactions[i].gasUsed;
            totalGasUsed += gasUsed;
            
            if (gasUsed > maxGasUsed) {
                maxGasUsed = gasUsed;
            }
            if (gasUsed < minGasUsed) {
                minGasUsed = gasUsed;
            }
        }
        
        uint256 averageGas = totalGasUsed / txCount;
        uint256 recommendedLimit = averageGas + (averageGas * 20 / 100);
        
        uint256 potentialSavings = 0;
        if (maxGasUsed > recommendedLimit) {
            potentialSavings = (maxGasUsed - recommendedLimit) * txCount;
        }
        
        return OptimizationRecommendation({
            averageGasUsed: averageGas,
            recommendedGasLimit: recommendedLimit,
            potentialSavings: potentialSavings,
            transactionCount: txCount,
            hasRecommendation: true
        });
    }
    
    receive() external payable {}
}
