// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title StaxerFactory
 * @dev Deploy the SalaryContract, Airdrop Contract and/or VAT Contract
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
 */
contract StaxerFactory is Ownable{

    enum ContractType{
        SALARY,
        CAPITALGAINS,
        VAT,
        RETURNS
    }

    struct UserInformation {
        address user;
        address salaryContractAddress;
        address capitalGainsContractAddress;
        address valueAddedTaxContractAddress;
        address returnsContractAddress;
    }

    mapping(address => UserInformation) userData;
    
    event DeployedContract(address _user, address _contract);

    constructor() Ownable(msg.sender) {
        
    }

    function deployContract(string memory _name, ContractType _type, address[] memory _waccounts, 
    uint[] memory _wpercentage, address[] memory _caccounts, 
    uint[] memory _cpercentage, string[] memory _tokenName, address[] memory _whitelistedAddress, bool _isWhiteList) public returns(address safeAddress){
        string memory cType;
        if(_type == ContractType.SALARY) {
            cType = "salaryContract";
            StaxerSafe staxer = new StaxerSafe(msg.sender, _name, cType, _waccounts, _wpercentage, _caccounts, _cpercentage, _tokenName, _whitelistedAddress, _isWhiteList);
            UserInformation storage userDetails = userData[msg.sender];
            if(userDetails.user == address(0)){
                userDetails.user = msg.sender;
            }
            userDetails.salaryContractAddress = address(staxer);
            emit DeployedContract(msg.sender, address(staxer));
            return address(staxer);
        }
         else if(_type == ContractType.CAPITALGAINS) {
            cType = "Capital Gains";
            StaxerSafe staxer = new StaxerSafe(msg.sender, _name, cType, _waccounts, _wpercentage, _caccounts, _cpercentage, _tokenName, _whitelistedAddress, _isWhiteList);
            UserInformation storage userDetails = userData[msg.sender];
            if(userDetails.user == address(0)){
                userDetails.user = msg.sender;
            }
            userDetails.capitalGainsContractAddress = address(staxer);
            emit DeployedContract(msg.sender, address(staxer));
            return address(staxer);
        }
        else if(_type == ContractType.VAT) {
            cType = "VAT";
            StaxerSafe staxer = new StaxerSafe(msg.sender, _name, cType, _waccounts, _wpercentage, _caccounts, _cpercentage,_tokenName, _whitelistedAddress, _isWhiteList);
            UserInformation storage userDetails = userData[msg.sender];
            if(userDetails.user == address(0)){
                userDetails.user = msg.sender;
            }
            userDetails.valueAddedTaxContractAddress = address(staxer);
            emit DeployedContract(msg.sender, address(staxer));
            return address(staxer);
        }
        else if(_type == ContractType.RETURNS) {
            cType = "Returns";
            StaxerSafe staxer = new StaxerSafe(msg.sender, _name, cType, _waccounts, _wpercentage, _caccounts, _cpercentage,_tokenName, _whitelistedAddress, _isWhiteList);
            UserInformation storage userDetails = userData[msg.sender];
            if(userDetails.user == address(0)){
                userDetails.user = msg.sender;
            }
            userDetails.returnsContractAddress = address(staxer);
            emit DeployedContract(msg.sender, address(staxer));
            return address(staxer);
        }

    }

    function getUserStruct(address _user) public view returns(UserInformation memory) {
        return userData[_user];
    }
}

contract StaxerSafe {
    address user;
    string safeName;
    bool isWhiteList;
    string contractType;
    mapping(address => uint) withHoldingAccountBalances;
    mapping(address => uint) cashAccountBalances;
    mapping(address => bool) whitelistedAddress;
    mapping(string => address) whitelistedTokenAddress;

    address[] cashAccounts;
    address[] withHoldingAccounts;

    event Deposit(address _sender, uint _amount);
    event ERC20TokenTransferred(string tokenName, address sender, uint currentBalance);
    event AmountCalculated(uint amount);

    constructor(address _user, string memory _name, string memory _type, address[] memory _waccounts, 
        uint[] memory _wpercentage, address[] memory _caccounts, 
        uint[] memory _cpercentage, string[] memory _tokenName, 
        address[] memory _whitelistedAddress, bool _isWhiteList) {
        
        uint cTotalPercentage;
        uint wTotalPercentage;
        safeName = _name;
        contractType = _type;
        user = _user;
        require(_waccounts.length == _wpercentage.length, "Accounts and percentage arrays should be of the same size!");
        require(_caccounts.length == _cpercentage.length, "Accounts and percentage arrays should be of the same size!");
        
        //Populate the withholding accounts and percentages
        for(uint i = 0; i < _waccounts.length; i++) {
            withHoldingAccounts.push(_waccounts[i]);
            withHoldingAccountBalances[_waccounts[i]] = _wpercentage[i];
            wTotalPercentage += _wpercentage[i];
        }

        //Populate the cash accounts and percentages
        for(uint i = 0; i < _caccounts.length; i++) {
            cashAccounts.push(_caccounts[i]);
            cashAccountBalances[_caccounts[i]] = _cpercentage[i];
            cTotalPercentage += _cpercentage[i];
        }

        //Add the whitelisted addresses to the contract if they exist
        isWhiteList = _isWhiteList;
        if(isWhiteList) {
            require(_tokenName.length == _whitelistedAddress.length, "Token name and addresses are not the same");
            for(uint i = 0; i < _whitelistedAddress.length; i++) {
                whitelistedAddress[_whitelistedAddress[i]] = true;
                whitelistedTokenAddress[_tokenName[i]] = _whitelistedAddress[i];
            }
        }

        uint totalPercentage = cTotalPercentage + wTotalPercentage;

        require(totalPercentage <= 100, "Total percentage distribution can't be more than a 100");
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }


    function claimAndSplitERC20Token(string memory tokenName, uint256 amount) public {
        uint currentBalance = IERC20(whitelistedTokenAddress[tokenName]).balanceOf(address(this));
        require(currentBalance >= amount, "Current balance is lesser than amount");

        IERC20(whitelistedTokenAddress[tokenName]).approve(address(this), currentBalance);

        uint amountCash;
        uint amountWithHolding;
        address withHoldingAddr;
        address cashAddr;

        //Distribute the balances in withholding wallets
        for(uint i = 0; i < withHoldingAccounts.length; i++) {
            withHoldingAddr = withHoldingAccounts[i];
            if(withHoldingAccountBalances[withHoldingAddr] != 0) {
                amountWithHolding = (currentBalance * withHoldingAccountBalances[withHoldingAddr])/100;
                emit AmountCalculated(amountWithHolding);
            }   

            if(amountWithHolding != 0){
                IERC20(whitelistedTokenAddress[tokenName]).transfer(withHoldingAddr, amountWithHolding);
            }

        }

        //Distribute the balances in the cash account wallets
        for(uint i = 0; i < cashAccounts.length; i++) {
            cashAddr = cashAccounts[i];
            if(cashAccountBalances[cashAddr] != 0) {
                amountCash = (currentBalance * cashAccountBalances[cashAddr])/100;
                emit AmountCalculated(amountCash);
            }   

            if(amountCash != 0){
                IERC20(whitelistedTokenAddress[tokenName]).transfer(cashAddr, amountCash);
            }
        }
        
        emit ERC20TokenTransferred(tokenName, msg.sender, currentBalance);
    }

    //TBD - Write the function to split Ether
    /** GET FUNCTIONS **/
    //Get the cash accounts of the user
    function getCashAccounts() public view returns(address[] memory) {
        return cashAccounts;
    }

    function getCashAccountBalance() public view returns(uint){
        uint balance;
        for(uint i = 0; i < cashAccounts.length; i++) {
            balance += cashAccountBalances[cashAccounts[i]];
        }

        return balance;
    }


     //Get the witholding accounts of the user
    function getWithHoldingAccounts() public view returns(address[] memory) {
        return withHoldingAccounts;
    }

     function getWithdrawalAccountBalance() public view returns(uint){
        uint balance;
        for(uint i = 0; i < withHoldingAccounts.length; i++) {
            balance += withHoldingAccountBalances[withHoldingAccounts[i]];
        }

        return balance;
    }
}
