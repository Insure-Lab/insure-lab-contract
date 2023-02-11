// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;
import "./interfaces/IERC20.sol";
contract Governance {


    // ============================
    // STATE VARIABLE
    // ============================

    uint ID = 1;
    uint public totalDAOMembers;
    uint public totalDAOFund;
    uint public totalVotingPower;
    uint public joinDAOMinimum;
    uint public joinDAOMaximum;
    uint totalGovernanceFee;
    address admin;
    address tokenAddress;
    address insuranceAddress;

    struct ClaimRequests {
        uint amountRequested;
        string description;
        string protocolName;
        string protocolDomain;
        address riskProvider;
        address claimer;
        uint claimRequestDate;
        uint insuranceID;
        address[] membersvoted;
        uint totalVote;
        bool claimable;
    }

    struct DAOMembers {
        uint Amount;
        uint votePower;
        bool joined;
    }



    mapping (address => DAOMembers) MemberData;
    address[]  MembersOfDAO;
    DAOMembers[] AllMembers;
    mapping (uint => ClaimRequests) Requests;
    ClaimRequests[] allRequests;


    // ============================
    // CONSTRUCTOR
    // ============================

    constructor (
        address _tokenAddress, 
        address _insuranceAddress,
        uint _minimumJoinDAO,
        uint _maximumJoinDAO) {
        admin = msg.sender;
        tokenAddress = _tokenAddress;
        insuranceAddress = _insuranceAddress;
        joinDAOMinimum = _minimumJoinDAO;
        joinDAOMaximum = _maximumJoinDAO;
    }


     // =============================
    //            EVENTS
    // ==============================

    event JoinedDAO (address member, uint amount);


    // ***************** //
    
     // WRITE FUNCTIONS
    
     // ***************** //


    /// @notice Function is called to join the DAO
    /// @dev This funciton allows users to join DAO while depositing into the contract
    /// @param _joinAmount: This is the amount the user is wiling to useto join the DAO
  
    function joinDAO (
        uint _joinAmount
    ) 
        public 
    {   
        DAOMembers storage members = MemberData[msg.sender];
        require(members.joined == false, "You have already joined DAO");
        require(_joinAmount >= joinDAOMinimum && _joinAmount <= joinDAOMaximum, "You are not within the range of amount");
        bool deposited = deposit(_joinAmount);
        require(deposited == true, "Deposit couldn't join DAO");
        members.Amount += _joinAmount;
        members.joined = true;
        uint votingPower = votePower(_joinAmount) / 1e6;
        members.votePower = votingPower;
        AllMembers.push(members);
        totalDAOMembers++;  
        totalDAOFund += _joinAmount;
        totalVotingPower += votingPower;
        MembersOfDAO.push(msg.sender);
        emit JoinedDAO (msg.sender, _joinAmount);
    }


    function vote (
        uint _id) 
            public 
    {
        ClaimRequests storage claim = Requests[_id];
        DAOMembers memory members = MemberData[msg.sender];
        require(members.joined == true, "You are not a member of the DAO");
        require(block.timestamp <= ( claim.claimRequestDate + 2 days), "Voting time over");
        bool voted = checkIfVoted(msg.sender, _id);
        require(voted != true, "you can't vote twice");
        uint voteCount = members.Amount;
        claim.totalVote += voteCount;
        uint requireVote = claimRequiredVoting();
        if (claim.totalVote >= requireVote) {
            claim.claimable = true;
        }
    }

    function userWithdrawInsurance (
        uint _idClaimRequests) 
        public 
    {   
        onlyInsureContract();
        ClaimRequests storage claim = Requests[_idClaimRequests];
        require(claim.claimable == true, "You can't claim grant");
        withdraw(claim.claimer, claim.amountRequested);
    }

    function riskAssessorWithdrawInsurance (
        uint _idClaimRequests) 
        public 
        returns (uint _insuranceID, uint refund)
    {
        onlyInsureContract();
        ClaimRequests storage claim = Requests[_idClaimRequests];
        require(block.timestamp >= ( claim.claimRequestDate + 2 days), "Voting time is not over");
        require(claim.claimable == false, "You can't claim grant back");
        withdraw(msg.sender, claim.amountRequested);
        _insuranceID = claim.insuranceID;
        refund = claim.amountRequested;
    }

    /// @notice Function is called by from the insurance contract when there is a request for cover
    /// @dev This is funciton that allows the users from the insurance contract request for their claim
    /// @param _amountRequest: This is the amount of cover requested from the user
    /// @param _description: This is the reason given be the user to get their claims.

    function requestCoverClaim (
        uint _amountRequest,
        string memory _description,
        string memory _protocolName,
        address _riskProvider,
        address _claimerAddress,
        uint _insuranceID)
        public 
    {
        onlyInsureContract();
        bool deposited = deposit(_amountRequest);
        require(deposited == true, "Deposit failed claim request failed");
        ClaimRequests storage claim = Requests[ID];
        claim.amountRequested = _amountRequest;
        claim.description = _description;
        claim.protocolName = _protocolName;
        claim.riskProvider = _riskProvider;
        claim.claimRequestDate = block.timestamp;
        claim.claimer = _claimerAddress;
        claim.insuranceID = _insuranceID;
        allRequests.push(claim);
        ID++;
    }

    function claimGovernanceFee
        () 
        public
    {
        
    } 

    function depositGovernanceFee (
        uint _amount
    ) 
        external 
    {
        onlyInsureContract();
        bool deposited = deposit(_amount);
        require (deposited == true, "Governance fee not deposited");
        totalGovernanceFee += _amount;
    }

    function setMinimumToJoinDAO ( uint _minimumJoinDAO) 
        public 
    { 
        onlyAdmin();
        joinDAOMinimum = _minimumJoinDAO;
    }

    function setMaximumToJoinDAO (uint _maximumJoinDAO)
        public
    {
        onlyAdmin();
        joinDAOMaximum = _maximumJoinDAO;
    }

   
    // ***************** //
    // VIEW FUNCTIONS
    // ***************** //

    function votePower (uint bal) internal view returns (uint power) {
        power = (bal * 1e6)/joinDAOMinimum;
    }

    function checkIfVoted (
        address _member,
        uint _id) 
        internal 
        view
        returns (bool status)
    {
        address[] memory voters = Requests[_id].membersvoted;
        for (uint i = 0; i <  voters.length; i++) {
            if (voters[i] == _member) {
                status = true;
            }
        }
    }

     function claimRequiredVoting () public view returns(uint result) {
        result = (60 * totalVotingPower) / 100;
    }


    // ***************** //
    // INTERNAL FUNCTIONS
    // ***************** //

     /// @notice Function to deposit ERC20 token into the contract 
    /// @dev This is an internal funcion called by different functions to deposit ERC20 token into the contract 
    /// @return sent the return variables of a contract’s function state variable
     function deposit(
        uint _amount) 
         internal 
         returns (bool sent)
    {
        amountMustBeGreaterThanZero(_amount);
        sent = IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount);
    }

    function withdraw (
        address _to,
        uint _amount)
        private
        returns (bool sent)
    {
        amountMustBeGreaterThanZero(_amount);
        sent = IERC20(tokenAddress).transfer(_to, _amount);
    }


    /// @notice this is the internal function used to check that address must be greater than zero
    /// @param _amount: this is the amount you want to check
    function amountMustBeGreaterThanZero(uint _amount) internal pure {
        require(_amount > 0, "Amount must be greater than zero");
    }

    function onlyInsureContract () internal view{
        require (msg.sender == insuranceAddress, "Only insurance contract can call this function");
    }

    /// @dev This is a private function used to allow only an admin call a function
    function onlyAdmin () 
        private 
        view
    {
        require(msg.sender == admin, "Not admin");
    }
  
 
}