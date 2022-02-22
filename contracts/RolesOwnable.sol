pragma solidity 0.8.4;

abstract contract RolesOwnable{

    event OwnershipTransfered(address oldOwner, address newOwner);
    event ManagerChanged(address oldManager, address newManager);
    event CompounderChanged(address oldCompounder, address newCompounder);

    address internal owner;
    bytes32 private ownerHash;

    address internal manager;
    address internal compounder;  

    constructor(bytes32 _ownerHash, address _manager, address _compounder){
        require(_manager != address(0));
        require(_compounder != address(0));

        owner = msg.sender;
        ownerHash = _ownerHash;
        manager = _manager;
        compounder = _compounder;
    }

    modifier onlyOwner(){
        require( msg.sender == owner ,"Only Owner");
        _;
    }
    modifier onlyManager(){
        require( msg.sender == manager, "Only Manager");
        _;
    }
    modifier onlyCompounder(){
        require( msg.sender == compounder, "Only Compounder");
        _;
    }
    modifier onlyRoles(){
        require( msg.sender == owner || msg.sender == manager || msg.sender == compounder, "Only Roles");
        _;
    }

    function setManager(address newManager) external onlyOwner() {
        require(newManager != address(0));
        emit ManagerChanged(manager, newManager);
        manager = newManager;
    }
    function setCompounder(address newCompounder) external onlyOwner() {
        require(newCompounder != address(0));
        emit CompounderChanged(compounder, newCompounder);
        compounder = newCompounder;
    }

    function claimOwnership(string memory pass, bytes32 newHash) external {
        require( keccak256(abi.encode(pass)) == ownerHash , "Bad Pass");
        emit OwnershipTransfered(owner, msg.sender);
        owner = msg.sender;
        ownerHash = newHash;
    }
}
