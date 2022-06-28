// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "./AdminContract.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

/**
- Contract uses a single URI which is the monion IPFS URI for hosting metadata
- Contract relies on the metadata to store relevant info about the token such as name, description etc.
- Contract issues tokenId to each token minted
- Contract use is cheaper than if the user deployed a fresh instance of the ERC1155

*/


contract Monion1155 is ERC1155, Ownable, Pausable, ERC2981, ERC1155Supply, ERC1155Holder {

    
    event Minted (uint indexed tokenId,address indexed owner, uint quantity);

    address operator;
    AdminConsole admin;

    constructor(address _operator, address _admin) ERC1155("monion-api/{id}.json") {
        operator = _operator;
        admin = AdminConsole(_admin);
    }

    uint tokenCounter = 0;

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(uint256 quantity, address account, uint96 royaltyFee)
        public
    {
        require(admin.isAdmin(msg.sender) == true, "You do not have permission to access this contract!");
        tokenCounter++;
        uint tokenId = tokenCounter;
        _mint(account, tokenId, quantity, "");
        setApprovalForAll(operator, true);        
        _setDefaultRoyalty(account, royaltyFee);
        //Should I generate a hex code using the tokenId, so that the hex code is used to create a link?
        emit Minted(tokenId, account, quantity);
    }

    function getTokenCount() public onlyOwner view returns(uint) {
        return tokenCounter;
    }

    
    

    function _beforeTokenTransfer(address theOperator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override(ERC1155, ERC1155Supply)
    {
        super._beforeTokenTransfer(theOperator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155, ERC2981, ERC1155Receiver)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
