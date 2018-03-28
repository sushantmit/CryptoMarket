pragma solidity ^0.4.16;

contract Ownable {
	address private owner;
	address public newOwner;

	event OwnershipTransferred(address indexed _from, address indexed _to);

	function Ownable() public {
		owner = msg.sender;
	}

	function getOwner() public constant returns (address currentOwner) {
		return owner;
	}

	modifier onlyOwner() {
		require(msg.sender == owner);
		_;
	}

	// Ownership can be transfered by current owner only
    // New owner should be a non-zero address
	function transferOwnership(address _newOwner) onlyOwner {
		require(_newOwner != address(0));
		newOwner = _newOwner;
	}

	// Ownership can be accepted by the new onwer only
    // Fires an Ownership transfer event
    function acceptOwnership() public {
        require(msg.sender == newOwner);
        OwnershipTransferred(owner, newOwner);
        owner = newOwner;
        newOwner = address(0);
    }

}

contract ERC721 {
	// Required methods
    function totalSupply() public view returns (uint256 total);	
    function balanceOf(address _owner) public view returns (uint256 balance);
    function ownerOf(uint256 _tokenId) public view returns (address owner);
    function approve(address _to, uint256 _tokenId) external;
    function transfer(address _to, uint256 _tokenId) external;
    function transferFrom(address _from, address _to, uint256 _tokenId) external;

    // Optional
    //function getName() public view returns (string tokenName);
    //function getSymbol() public view returns (string tokenSymbol);
    function tokensOfOwner(address _owner) external view returns (uint256[] tokenIds);
    //function tokenMetadata(uint256 _tokenId, string _preferredTransport) public view returns (string infoUrl);

    // Events
    event Transfer(address from, address to, uint256 tokenId);
    event Approval(address owner, address approved, uint256 tokenId);

}

contract NFToken is ERC721, Ownable {
    struct NFTokens {

        // Creation price
        uint256 createPrice;
        // Timestamp represting the time when this token came into existence;
        uint256 createTime;
    }

    // Array representing each token in existence
    NFTokens[] nfts;

    // Owner of each token is represnted by this mapping
    // Each token has a non-zero owner
    mapping (uint256 => address) private tokenToOwner;

    // This represents the number of tokens held by each owner
    mapping (address => uint256) private tokenOwnershipCount;
    // Mapping that allows an address to transfer a particular token
    mapping (uint256 => address) public tokenApproved;

    uint256 tokensInSupply;

    event Minted(address indexed owner, uint256 indexed tokenID);

    function totalSupply() public view returns (uint256 total) {
        return tokensInSupply;
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return tokenOwnershipCount[_owner];
    }

    function ownerOf(uint256 _tokenId) public view returns (address gemOwner) {
        return tokenToOwner[_tokenId];
    }

    // Any verification must be done in calling function
    // This is just an internal function to be called by functions such as transfer and transferFrom
    function _transfer(address _from, address _to, uint256 _tokenId) internal {

        tokenOwnershipCount[_to]++;
        // transfer ownership
        tokenToOwner[_tokenId] = _to;
        // When creating new token, _from is 0x0, but we can't account that address.
        if (_from != address(0)) {
            tokenOwnershipCount[_from]--;
            // clear any previously approved ownership exchange
            delete tokenApproved[_tokenId];
        }
        // Emit the transfer event.
        Transfer(_from, _to, _tokenId);
    }

    // Any verification must be done in calling function
    // This is just an internal function to be called by functions such as approve
    function _approve(address _to, uint256 _tokenId) internal {
        tokenApproved[_tokenId] = _to;
        // Event genrated in calling function as _from is required
    }

    // Checks if a given address (claimant) is actually the owner of the token
    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return tokenToOwner[_tokenId] == _claimant;
    }

    // Checks if a given address (claimaint) is actually approved for the token
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return tokenApproved[_tokenId] == _claimant;
    }

    function transferFrom(address _from, address _to, uint256 _tokenId) external {
        // Check if function caller is approved for the token
        require(_approvedFor(msg.sender, _tokenId));
        // Check if _from owns the token
        require(_owns(_from, _tokenId));
        // Do not allow tokens to be sent to 0x0 address
        require(_to != address(0));
        // Do not allow tokens to be sent to this contarct
        require(_to != address(this));
        // Calling internal function to transfer and clear pending approvals
        _transfer(_from, _to, _tokenId);
    }

    function approve(address _to, uint256 _tokenId) external {
        // Check if function caller is the owner of the token
        require(_owns(msg.sender, _tokenId));
        // Calling internal function to approve the _to the address
        _approve(_to, _tokenId);
        // Emit the Approval event here as it is not done in the internal function
        Approval(msg.sender, _to, _tokenId);
    }

    // Returns a list of all tokenIDs owned by an address.
    // Must not be called by contracts as it uses dynamic array which is supported for only
    // web3 calls and not contract-to-contract calls.
    // Also this method is fairly expensive if called internally as it iterates through the whole collection of created tokens
    function tokensOfOwner(address _owner) external view returns(uint256[] ownerTokens) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array
            return new uint256[](0);
        } 
        else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalTokens = totalSupply();
            uint256 resultIndex = 0;

            // We start counting from the first token with tokenID 0 and count upto the totalTokens
            uint256 tokenId;

            for (tokenId = 0; tokenId <= totalTokens; tokenId++) {
                if (tokenToOwner[tokenId] == _owner) {
                    result[resultIndex] = tokenId;
                    resultIndex++;
                }
            }

            return result;
        }
    }

    function _createTokens(
        uint256 _value,
        address _owner
    )
        internal
        returns (uint)
    {
        NFTokens memory _token = NFTokens({
            createPrice: _value,
            createTime: uint64(now)
        });
        
        uint256 newTokenId = nfts.push(_token)-1;

        // emit the Mined event
        Minted(_owner, newTokenId);

        // This will assign ownership, and also emit the Transfer event as
        // per ERC721 draft
        _transfer(0, _owner, newTokenId);
        tokensInSupply++;

        return newTokenId;
    }

    // Function to create new tokens
    // Calls the internal fucntion _createTokens
    // Only callable by owner fo the contract to create promo tokens to be sold at promo price to users
    //(Could add a limit here to make sure only a few promo tokens can be created - making them exclusive)
    function createNewTokens(
        uint256 promoPrice
    )
    external onlyOwner
    returns (uint) {
        _createTokens(promoPrice, msg.sender);
    }

    function mintNewToken() public payable {
        
        _createTokens(msg.value, msg.sender);
    }

    
}