pragma solidity 0.8.4;
import "./RolesOwnable.sol";
import "./interfaces/IERC20.sol";
interface IStrategy{
    function deposit(bytes calldata data) external;
    function withdraw(bytes calldata data) external;
    function compound() external;
}
/// @notice A smart contract to safely manage your investments
/// There are 3 different roles:
///     * Owner : The owner can change the other roles, cancel transactions, withdraw tokens and set Trustful strategy contracts
///     * Manager : The manager can submit investments transactions
///     * Compounder : The compounder can submit compounding transactions
/// For each investment transaction, there is a fixed delay of 1 day for it to become executable
/// All roles can execute the transactions once executable
/// @dev Strategy contracts must expose an interface of type "IStrategy"
/// Strategies can access the funds of the HunWallet only during a "deposit" call
contract HunWallet is RolesOwnable{

    uint private TRANSACTION_DELAY = 1 days;
    enum TransactionType{ DEPOSIT, WITHDRAW, COMPOUND }

    bool private transactioning = false;

    mapping(address => bool) private trustedStrategies;

    struct Transaction{
        address strategy;
        TransactionType trType;
        bytes data;
        uint timeOfSubmission;
        bool executed;
    }
    Transaction[] private transactions;
    uint private transactionCount;

    modifier onlyDuringTransaction() {
        require( transactioning ,"Not allowed");
        _;
    }

    modifier onlyTrustedStrategies(address strategy){
        require( trustedStrategies[strategy] , "Bad Strategy");
        _;
    }

    modifier onlyValidRole( TransactionType trType ){
        if (trType == TransactionType.COMPOUND) {
            require( msg.sender == compounder ,"Only compounder");
        }
        else {
            require( msg.sender == manager ,"Only manager" );
        }
        _;
    }

    constructor(bytes32 _ownerHash, address _manager, address _compounder) RolesOwnable(_ownerHash, _manager, _compounder) {
    }

    //*//*// ======== OWNER'S FUNCTIONS ======== //*//*//

    function trustStrategy( address strategy ) external onlyOwner() {
        require( strategy != address(0) );
        trustedStrategies[ strategy ] = !trustedStrategies[ strategy ];
    }
    function cancel( uint trID ) external onlyOwner(){
        require( trID < transactionCount, "Transaction does not exist");
        transactions[ trID ].executed = true; 
    }
    function withdrawToken( address token, uint amount ) external onlyOwner(){
        require( IERC20( token ).transfer( owner, amount ) );
    }

    //*//*// ======== STRATEGIES' FUNCTIONS ======== //*//*//

    function getFund( address token, uint amount ) external onlyDuringTransaction() onlyTrustedStrategies(msg.sender) {
        require( IERC20( token ).transfer( msg.sender, amount) );
    }
    
    //*//*// ======== SHARED FUNCTIONS ======== //*//*//

    /// @notice Submits a transaction of type trType
    /// @return trID : the transaction ID
    function submit( address strategy, TransactionType trType, bytes calldata data ) external onlyValidRole(trType) onlyTrustedStrategies(strategy) returns( uint trID ) {
        transactions.push( Transaction(
            strategy, trType, data, block.timestamp, false
        ) );
        trID = transactionCount;
        transactionCount += 1;
    }
    /// @notice Executes the transaction with ID trID
    function execute( uint trID ) external onlyRoles(){
        require( trID < transactionCount, "Transaction does not exist");
        Transaction memory transaction = transactions[ trID ];
        require( !transaction.executed, "Already executed");
        require( block.timestamp > transaction.timeOfSubmission + TRANSACTION_DELAY, "Transaction not ready");

        if(transaction.trType == TransactionType.DEPOSIT){
            transactioning = true;
            IStrategy( transaction.strategy ).deposit( transaction.data );
            transactioning = false;
        }else if(transaction.trType == TransactionType.WITHDRAW){
            IStrategy( transaction.strategy ).withdraw( transaction.data );
        }else{
            IStrategy( transaction.strategy ).compound();
        }

        transactions[ trID ].executed = true;
    }

    function unApprove( address token, address to ) external onlyRoles(){
        require( IERC20( token ).approve(to, 0) );
    }
}