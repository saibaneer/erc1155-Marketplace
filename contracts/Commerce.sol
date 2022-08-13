// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./NFTStorage.sol";
import "./AdminContract.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "hardhat/console.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Commerce is ReentrancyGuard {


    event SendOffer(uint indexed tokenId,address nftAddress, address tokenOwner, uint indexed quantity, address sender, uint offer, uint indexed index);
    event AcceptedOffer(uint indexed tokenId,address nftAddress, address indexed seller, address buyer, uint quantity, uint indexed index);
    event WithdrewOffer(uint indexed tokenId,address nftAddress, address tokenOwner, address indexed caller, uint amount, uint index);
    event UpdatedOffer(uint indexed tokenId,address nftAddress, address tokenOwner, address indexed caller,uint prevPrice, uint amount, uint index);
    event WithdrewNFT(uint tokenId,address nftAddress, address owner, uint quantity);
    event WithdrewFunds(address indexed caller, uint indexed amount);
    event WithdrewMarketFunds(address indexed caller, uint indexed amount);


    MyNFTStorage vault;
    AdminConsole admin;
    address immutable owner;

    constructor(address _vault, address _admin) ReentrancyGuard() {
        vault = MyNFTStorage(_vault);
        admin = AdminConsole(_admin);
        owner = msg.sender;
    }

    struct Offers {
        address sender;
        address nftAddress;
        uint qty;
        uint price;
        uint totalPrice;
        
    }

    // mapping(uint => mapping(address => uint)) public deposits;
    mapping(address => uint) public deposits;
    mapping(address => mapping(uint => mapping(address => Offers[]))) public buyOffers;
    mapping(address => mapping(uint => mapping(address => bool))) public alreadyOffered;

    function sendBuyOffer(address nftAddress, uint tokenId, address tokenOwner, uint quantity) payable public {     
        
        require(vault.tokenExists(nftAddress, tokenId, tokenOwner) == true, "There are no units of this token available for sale!");
        require(tokenOwner != address(0), "You cannot order from this address!");
        require(nftAddress != address(0), "You cannot order from a zero nft address!");
        require(quantity > 0, "You cannot order negative quantity");
        require(quantity <= vault.getAvailableQty(nftAddress,tokenId, tokenOwner), "Seller does not have this units available for sale, reduce quantity!");
        
        uint price = vault.getTokenPrice(nftAddress, tokenId, tokenOwner);
        // address seller = vault.getTokenOwner(tokenId, tokenOwner);        

        uint totalPrice = price * quantity;
        require(msg.value >= totalPrice, "Insufficient amount for the chosen quantity!");
        require(alreadyOffered[nftAddress][tokenId][msg.sender] == false, "Withdraw current offer, and make new offer!");
        alreadyOffered[nftAddress][tokenId][msg.sender] = true; 

        Offers memory myOffer = Offers(msg.sender,nftAddress, quantity, price, msg.value);
        buyOffers[nftAddress][tokenId][tokenOwner].push(myOffer);
        uint length = buyOffers[nftAddress][tokenId][tokenOwner].length;
        uint id = length - 1;
        console.log("The index for this offer is: ", id);
        //add event with array id;
        emit SendOffer(tokenId, nftAddress, tokenOwner, quantity, msg.sender, msg.value, id);
    }

    function viewOffers(address nftAddress, uint tokenId, address tokenOwner) public view returns(Offers[] memory){
        require(msg.sender == tokenOwner || msg.sender == owner, "You are not authorized to to view Offers");
        uint length = buyOffers[nftAddress][tokenId][tokenOwner].length;
        Offers[] memory myOffers = new Offers[](length);

        Offers[] memory existingOffers = buyOffers[nftAddress][tokenId][tokenOwner];

        for(uint i = 0; i < myOffers.length; i++){
            myOffers[i] = existingOffers[i];
        }
        return myOffers;
    }

    function acceptOffer(address nftAddress, uint tokenId, uint index) external nonReentrant() {
        Offers memory acceptedOffer = buyOffers[nftAddress][tokenId][msg.sender][index];
        require(vault.isOwner(nftAddress, tokenId, msg.sender) == true, "You are not authorized!");
        require(vault.verifyQuantityIsAvailable(nftAddress, tokenId, msg.sender, acceptedOffer.qty) == true, "You do not have sufficient units to accept this token!");
        
        //get the creator, seller, and marketplace info
        uint dueMarketplace = acceptedOffer.price * (admin.getFeePercent()/10000);
        uint dueSeller = acceptedOffer.price - dueMarketplace;
        (address creator, uint dueCreator) = IERC2981(nftAddress).royaltyInfo(tokenId, dueSeller);
        dueSeller -= dueCreator;

        deposits[msg.sender] += dueSeller;
        deposits[admin.getFeeAccount()] += dueMarketplace;
        deposits[creator] += dueCreator;
                
        address buyer = acceptedOffer.sender;
        uint quantity = acceptedOffer.qty;

        vault._claimToken(nftAddress, tokenId, msg.sender, acceptedOffer.sender, acceptedOffer.qty);
        alreadyOffered[nftAddress][tokenId][acceptedOffer.sender] = false; 
        Offers[] storage allOffers = buyOffers[nftAddress][tokenId][msg.sender];
        allOffers[index] = allOffers[allOffers.length - 1];
        allOffers.pop();

        emit AcceptedOffer(tokenId, nftAddress, msg.sender, buyer, quantity, index);
        
    }

    function withdrawOffer(address nftAddress, uint tokenId, address tokenOwner) external nonReentrant() {
        (bool hasOffer, uint index, uint amount) = offerExists(nftAddress, tokenId, tokenOwner, msg.sender);
        require(hasOffer, "Commerce: You do not have an existing offer!");
        Offers[] storage allOffer = buyOffers[nftAddress][tokenId][tokenOwner];       
        
        alreadyOffered[nftAddress][tokenId][msg.sender] = false;

        allOffer[index] = allOffer[allOffer.length - 1];
        allOffer.pop();

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to send Ether");
        
        emit WithdrewOffer(tokenId, nftAddress, tokenOwner, msg.sender, amount, index);
        
    }

    // function updateOffer(address nftAddress, uint tokenId, address tokenOwner, uint newQuantity) external payable {
    //     (bool hasOffer, uint index, uint old_totalPrice) = offerExists(nftAddress, tokenId, tokenOwner, msg.sender);
    //     require(hasOffer, "Commerce: You do not have an existing offer!");

    //     Offers memory myOffer = buyOffers[nftAddress][tokenId][tokenOwner][index];
    //     uint prevPrice = myOffer.totalPrice;



    //     myOffer.totalPrice += msg.value;

    //     emit UpdatedOffer(tokenId,nftAddress, tokenOwner, msg.sender,prevPrice, myOffer.totalPrice, index);
    // }

    function withdrawNFTs(address nftAddress, uint tokenId, uint quantity) external {
        vault._withdrawNFT(nftAddress, tokenId, msg.sender, quantity);

        emit WithdrewNFT(tokenId, nftAddress, msg.sender, quantity);
    }

    function withdrawFunds() payable public nonReentrant() {
        uint amount = deposits[msg.sender];
        deposits[msg.sender] = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Failed to send Ether");

        

        emit WithdrewFunds(msg.sender, amount);
    }

    function withdrawMarketfunds() payable external {
        address feeAccount = admin.getFeeAccount();
        require(msg.sender == feeAccount, "You are not authorized!");
        uint amount = deposits[feeAccount];
        deposits[feeAccount] = 0;
        (bool success, ) = payable(feeAccount).call{value: (amount*99)/100}("");
        require(success, "Failed to send Ether");

        

        emit WithdrewMarketFunds(feeAccount, amount);
    }

    function getDeposit() public view returns(uint){
        return deposits[msg.sender];
    }

    function offerExists(address nftAddress, uint tokenId, address tokenOwner, address account) internal view returns(bool answer, uint index, uint totalPrice) {
        Offers[] storage allOffers = buyOffers[nftAddress][tokenId][tokenOwner];
        uint length = allOffers.length;
        
        for(uint i = 0; i < length; i++){
            if(allOffers[i].sender == account){
                answer = true;
                index = i;
                totalPrice = allOffers[i].totalPrice;
            }
        }
        
    }

     

}