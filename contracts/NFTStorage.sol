
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./AdminContract.sol";
import "./ListingContract.sol";
import "./UserDefined1155.sol";
import "./Monion1155.sol";

contract MyNFTStorage is ERC1155Holder {

    UserDefined1155 minter;
    AdminConsole admin;
    Monion1155 monionMinter;

    uint feePercent; //Marketplace fee

    constructor(address _admin){
        // minter = Minter(_minterAddress);
        admin = AdminConsole(_admin);
        
    }
    
    

    

    struct Token {
        
        uint tokenId;
        uint tokenPrice;
        address owner;
        address nftAddress;
        uint quantity;
    }

    struct TokenItem {
        address nftAddress;
        uint[] tokenId;
    }

    //================LISTING MAPPINGS=========================
    mapping(address => mapping(uint => mapping(address => uint))) private tokenBalance; //nftAddress -> tokenId -> userAddress -> quantity
    mapping(address => mapping(uint => mapping(address => Token))) private tokenIdToUserToTokenInfo; //nftAddress -> userAddress -> TokenObject

    function _listUserDefinedNFTForSale(address nftAddress,uint tokenId, uint tokenPrice, address account, uint quantity) public { //please ensure that this remains internal
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        minter = UserDefined1155(nftAddress);
        uint tokensHeld = minter.balanceOf(account, tokenId);
        require(tokensHeld > 0, "This user does not have any units of this token available for listing!");
        require(quantity <= tokensHeld, "You cannot list this units of this token, try reducing the quantity!");

        tokenBalance[nftAddress][tokenId][account] += quantity;

        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][account];
        myToken.tokenId = tokenId;
        myToken.tokenPrice = tokenPrice;
        myToken.nftAddress = nftAddress;

        feePercent = admin.getFeePercent();
        myToken.tokenPrice = myToken.tokenPrice * (10000 + feePercent)/10000;        
        myToken.quantity += quantity;     
        myToken.owner = payable(account);
        
        minter.safeTransferFrom(account, address(this), tokenId, quantity, "");
    }

    function _listMonionNFTForSale(address nftAddress,uint tokenId, uint tokenPrice, address account, uint quantity) public { //please ensure that this remains internal
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        monionMinter = Monion1155(nftAddress);
        uint tokensHeld = monionMinter.balanceOf(account, tokenId);
        require(tokensHeld > 0, "NFT Storage: This user does not have any units of this token available for listing!");
        require(quantity <= tokensHeld, "You cannot list this units of this token, try reducing the quantity!");

        tokenBalance[nftAddress][tokenId][account] += quantity;

        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][account];
        myToken.tokenId = tokenId;
        myToken.tokenPrice = tokenPrice;
        myToken.nftAddress = nftAddress;
        feePercent = admin.getFeePercent();

        myToken.tokenPrice = myToken.tokenPrice * (10000 + feePercent)/10000;        
        myToken.quantity += quantity;     
        myToken.owner = payable(account);
        
        monionMinter.safeTransferFrom(account, address(this), tokenId, quantity, "");
    }


    function _claimToken(address nftAddress, uint tokenId, address owner, address account, uint quantity) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        

        //reduce previous owner's tokens
        Token storage ownerToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][owner];
        ownerToken.quantity -= quantity;
        tokenBalance[nftAddress][tokenId][owner] -= quantity;
        
        
        //increase new user's tokens
        Token storage newOwner= tokenIdToUserToTokenInfo[nftAddress][tokenId][account];
        newOwner.tokenId = tokenId;
        newOwner.nftAddress = nftAddress;
        newOwner.quantity += quantity;
        newOwner.owner = account;
        newOwner.tokenPrice = ownerToken.tokenPrice;
        tokenBalance[nftAddress][tokenId][account] += quantity;
    }

    function _withdrawNFT(address nftAddress, uint tokenId, address tokenOwner, uint quantity) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        //validate that he/she has the quantity
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][tokenOwner];
        require(myToken.owner == tokenOwner, "You do not own this token!");
        require(myToken.quantity > 0, "You do not have any tokens!");
        require(quantity <= myToken.quantity, "You do not have sufficient tokens, withdraw less!");

        //change state to reflect decrement
        tokenBalance[nftAddress][tokenId][tokenOwner] -= quantity;
        myToken.quantity -= quantity;
        minter = UserDefined1155(nftAddress);
        minter.safeTransferFrom(address(this), tokenOwner, tokenId, quantity, "");

    }

    function _reduceNFTUnits(address nftAddress, uint tokenId, address tokenOwner, uint quantity) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        //validate that he/she has the quantity
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][tokenOwner];
        
        require(myToken.owner == tokenOwner, "You do not own this token!");
        require(myToken.quantity > 0, "You do not have any tokens!");
        require(quantity <= myToken.quantity, "You do not have sufficient tokens, withdraw less!");

        //change state to reflect decrement
        tokenBalance[nftAddress][tokenId][tokenOwner] -= quantity;
        myToken.quantity -= quantity;
        minter = UserDefined1155(nftAddress);
        minter.safeTransferFrom(address(this), tokenOwner, tokenId, quantity, "");

    }
    

    function _delistNFT(address nftAddress, uint tokenId, address account) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][account];   
        require(myToken.owner == account, "You do not own this token!");
        minter = UserDefined1155(nftAddress);
        minter.safeTransferFrom(address(this), account, tokenId, myToken.quantity, "");
        tokenBalance[nftAddress][tokenId][account] = 0;
        myToken.quantity = 0;       

    }

    function _updateTokenPrice(address nftAddress, uint tokenId, address account, uint price) public {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");

        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][account];   
        require(myToken.owner == account, "You do not own this token!");
        myToken.tokenPrice = price;

    }

    

    function getTokenPrice(address nftAddress, uint tokenId, address account) public view returns(uint) {
        return tokenIdToUserToTokenInfo[nftAddress][tokenId][account].tokenPrice;
    }

    function getTokenOwner(address nftAddress, uint tokenId, address account) public view returns(address) {
        return tokenIdToUserToTokenInfo[nftAddress][tokenId][account].owner;
    }

    function getAvailableQty(address nftAddress, uint tokenId, address account) public view returns(uint) {
        return tokenIdToUserToTokenInfo[nftAddress][tokenId][account].quantity;
    }    

    function getToken(address nftAddress, uint tokenId, address account) public view returns(Token memory) {
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][account];
        return myToken;
    }

    function tokenExists(address nftAddress, uint tokenId, address tokenOwner) public view returns(bool) {
        //token exists if at least 1 unit exists
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][tokenOwner];
        if(myToken.quantity >= 1){
            return true;
        } else {
            return false;
        }
    }

    function isOwner(address nftAddress, uint tokenId, address tokenOwner) public view returns(bool) {
        //token exists if at least 1 unit exists
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][tokenOwner];
        if(myToken.owner == tokenOwner){
            return true;
        } else {
            return false;
        }
    }

    function verifyQuantityIsAvailable(address nftAddress, uint tokenId, address tokenOwner, uint quantity) public view returns(bool) {
        Token storage myToken = tokenIdToUserToTokenInfo[nftAddress][tokenId][tokenOwner];
        if(quantity <= myToken.quantity){
            return true;
        } else {
            return false;
        }
    }

    
}