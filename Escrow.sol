// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0;
contract Escrow {
    address payable judge;
    address payable buyer;
    address payable seller;
    uint256 public disputeResolutionTime = 100;
    uint256 public judgeFees = 500;
    uint256 depositTime;
    uint256 disputeRaisedTime;


    enum State {awaitPayment, awaitDelivery, transactionComplete}
    enum Dispute {no, yes}
    enum DisputeFeesBySeller {no, yes}


    State public currentState;
    Dispute public disputeState;
    DisputeFeesBySeller public disputeFeesBySeller;
    modifier onlyJudge() {
        require(msg.sender == judge, "Should be the Judge");
        _;
    }

    modifier onlyBuyer() {
        require(msg.sender == buyer, "Should be the Buyer");
        _;
    }

    modifier onlySeller() {
        require(msg.sender == seller, "Should be the Seller");
        _;
    }

    modifier checkState(State expectedState) {
        require(currentState == expectedState);
        _;
    }

    mapping(address => uint256) deposits;

    constructor(address payable _buyer, address payable _seller) public {
        judge = msg.sender;
        buyer = _buyer;
        seller = _seller;
        currentState = State.awaitPayment;
        disputeState = Dispute.no;
        disputeFeesBySeller = DisputeFeesBySeller.no;
    }

    //Deposit the amount by the buyer.
    function depositAmountByBuyer()
        public
        payable
        onlyBuyer
        checkState(State.awaitPayment)
    {
        depositTime = block.timestamp;
        currentState = State.awaitDelivery;
    }

    // //Check balance stored in the contract
    // function checkContractBalance() external view returns (uint256) {
    //     return address(this).balance;
    // }
    // function checkJudgeBalance() external view returns (uint256) {
    //     return deposits[judge];
    // }
    
    //Set the time to raise dispute after deposit
    function bufferTime(uint256 d_Time) private returns (uint256) {
        return depositTime + d_Time;
    }
    //Withdraw the amount and pay to the seller
    function withdrawBySeller()
        public
        checkState(State.awaitDelivery)
        onlySeller
    {
        // require withdrwal after 50 seconds
        require(block.timestamp > bufferTime(50), "Not the time to withdraw.");
        require(disputeState == Dispute.no, "Dispute Raised");
        uint256 payment = address(this).balance;
        seller.transfer(payment); //transfer complete payment to the seller
        currentState = State.transactionComplete;
    }

    //raise dispute
    function raiseDispute() public payable onlyBuyer checkState(State.awaitDelivery) {
        require(msg.value == judgeFees, "require judge fees");
        require(block.timestamp <= bufferTime(50), "Time to raise a dispute has passed.");
        deposits[judge] += msg.value;
        disputeState = Dispute.yes;
        disputeRaisedTime = block.timestamp;
    }
    //Function for seller to Pay Judge Fee
    function disputeFeeBySeller() public payable onlySeller() {
        require(disputeState == Dispute.yes, "Dispute Not Raised");
        require(msg.value == judgeFees, "require judge fees");
        require(block.timestamp <= disputeRaisedTime+disputeResolutionTime, "Time to pay a dispute fee has passed.");
        deposits[judge] = deposits[judge] + msg.value;
        disputeFeesBySeller = DisputeFeesBySeller.yes;
    }
    //Function for judge to resolve dispute
    function disputeResolution(address payable winner) public onlyJudge returns(address){
        require(disputeState == Dispute.yes, "No Dispute");
        require(block.timestamp >= disputeRaisedTime+disputeResolutionTime, "Dispute Time has not passed.");

        if(disputeFeesBySeller == DisputeFeesBySeller.yes){
            //Both Parties ready for dispute resolution 
            winner = winner;
            judge.transfer(deposits[judge]);
        }
        else if(disputeFeesBySeller == DisputeFeesBySeller.no){
            winner = buyer;
        }
        winner.transfer(address(this).balance);
        disputeState == Dispute.no;
        currentState = State.awaitPayment;
        return winner;
    } 
}
