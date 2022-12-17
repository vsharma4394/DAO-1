// SPDX-License-Identifier:MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ICryptoDevsNFT.sol";
import "./IFakeNFTMarketPlace.sol";

contract CryptoDevsDAO is Ownable {
    struct Proposal {
        uint256 nftTokenId;
        uint256 deadline;
        uint256 yayvotes;
        uint256 nayvotes;
        bool executed;
        mapping(uint256 => bool) voters;
    }
    mapping(uint256 => Proposal) public proposals;
    uint256 public numProposals;
    IFakeNFTMarketPlace nftMarketplace;
    ICryptoDevsNFT cryptoDevsNFT;

    constructor(address _nftMarketplace, address _cryptoDevsNFT) payable {
        nftMarketplace = IFakeNFTMarketPlace(_nftMarketplace);
        cryptoDevsNFT = ICryptoDevsNFT(_cryptoDevsNFT);
    }

    modifier nftHolderOnly() {
        require(cryptoDevsNFT.balanceOf(msg.sender) > 0, "NOT A DAO MEMBER");
        _;
    }
    modifier activeProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline > block.timestamp,
            "DEADLINE_EXCEEDED"
        );
        _;
    }
    modifier inactiveProposalOnly(uint256 proposalIndex) {
        require(
            proposals[proposalIndex].deadline <= block.timestamp,
            "Deadline not exceeded"
        );
        require(
            proposals[proposalIndex].executed == false,
            "PROPOSAL_ALREADY_EXECUTED"
        );
        _;
    }

    function createPurposal(
        uint _nfttokenId
    ) external nftHolderOnly returns (uint256) {
        require(nftMarketplace.available(_nfttokenId), "NFT Not for sale");
        Proposal storage proposal = proposals[numProposals];
        proposal.nftTokenId = _nfttokenId;
        proposal.deadline = block.timestamp + 5 minutes;
        numProposals++;
        return numProposals - 1;
    }

    enum Vote {
        Yay,
        Nay
    }

    function voteOnProposal(
        uint256 proposalindex,
        Vote vote
    ) external nftHolderOnly activeProposalOnly(proposalindex) {
        Proposal storage proposal = proposals[proposalindex];
        uint256 voterNFTBalance = cryptoDevsNFT.balanceOf(msg.sender);
        uint256 numVotes = 0;

        for (uint256 i = 0; i < voterNFTBalance; ++i) {
            uint256 tokenId = cryptoDevsNFT.tokenOfOwnerByIndex(msg.sender, i);
            if (proposal.voters[tokenId] == false) {
                numVotes++;
                proposal.voters[tokenId] = true;
            }
        }
        require(numVotes > 0, "Already voted");
        if (vote == Vote.Yay) {
            proposal.yayvotes += numVotes;
        } else {
            proposal.nayvotes += numVotes;
        }
    }

    function executeProposal(
        uint256 proposalIndex
    ) external nftHolderOnly inactiveProposalOnly(proposalIndex) {
        Proposal storage proposal = proposals[proposalIndex];
        if (proposal.yayvotes > proposal.nayvotes) {
            uint256 nftPrice = nftMarketplace.getPrice();
            require(address(this).balance >= nftPrice, "Not enough funds");
            nftMarketplace.purchase{value: nftPrice}(proposal.nftTokenId);
        }
        proposal.executed = true;
    }

    function withdrawEther() external onlyOwner {
        uint256 amount = address(this).balance;
        require(amount > 0, "Nothing to withdraw; contract balance empty");
        payable(owner()).transfer(amount);
    }

    receive() external payable {}

    fallback() external payable {}
}
