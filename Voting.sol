// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is Ownable {

    struct Voter {
        bool isRegistered;
        bool hasVoted;
        uint votedProposalId;
    }

    // Les électeurs inscrits
    // peuvent soumettre de nouvelles propositions lors d'une session d'enregistrement des propositions, 
    // et peuvent voter sur les propositions lors de la session de vote.
    mapping (address => Voter) whitelist;

    // Propositions
    struct Proposal {
        string description;
        uint voteCount;
    }

    // Tableau des propositions
    Proposal[] proposals;

    // gère les différents états d’un vote
    enum WorkflowStatus {
        RegisteringVoters,
        ProposalsRegistrationStarted,
        ProposalsRegistrationEnded,
        VotingSessionStarted,
        VotingSessionEnded,
        VotesTallied
    }

    // Statut courant du vote
    WorkflowStatus defaultstate;


    // représente l’id du gagnant
    uint winningProposalId;


    // Evenements
    event VoterRegistered(address voterAddress); 
    event WorkflowStatusChange(WorkflowStatus previousStatus, WorkflowStatus newStatus);
    event ProposalRegistered(uint proposalId);
    event Voted (address voter, uint proposalId);
 

    // L’administrateur est celui qui va déployer le smart contract. 
    constructor(address initialOwner)
        Ownable(initialOwner)
    {}

    // Vérifier que le votant est whitelisté
    modifier isWhitelisted() {
        require(whitelist[msg.sender].isRegistered,"Vous n'etes pas autorise a voter");
        require(!whitelist[msg.sender].hasVoted,"Vous n'etes pas autorise a revoter");
        
        _;
    }

    // L'administrateur du vote enregistre une liste blanche d'électeurs identifiés par leur adresse Ethereum.
    // L'administrateur peut whitelister un candidat
    function setWhitelist(address _address) external onlyOwner {
        whitelist[_address].isRegistered = true;
        emit VoterRegistered(_address);         
    }

    function startProposalsRegistration() public onlyOwner {
        defaultstate = WorkflowStatus.ProposalsRegistrationStarted;

        emit WorkflowStatusChange(defaultstate, WorkflowStatus.ProposalsRegistrationStarted);

    }

    // L'administrateur de vote met fin à la session d'enregistrement des propositions
    function endProposalsRegistration() public onlyOwner {
        defaultstate = WorkflowStatus.ProposalsRegistrationEnded;

        emit WorkflowStatusChange(defaultstate, WorkflowStatus.ProposalsRegistrationEnded);
    }

    // Demarrer la session de vote
    function startVotingSession() public onlyOwner {
        defaultstate = WorkflowStatus.VotingSessionStarted;

        emit WorkflowStatusChange(defaultstate, WorkflowStatus.VotingSessionStarted);
    
    }

    // L'administrateur de vote met fin à la session d'enregistrement des propositions
    function endVotingSession() public onlyOwner {
        require(defaultstate == WorkflowStatus.VotingSessionStarted, "La fin du vote n'est pas possible a cette etape");
        
        defaultstate = WorkflowStatus.VotingSessionEnded;

        emit WorkflowStatusChange(defaultstate, WorkflowStatus.VotingSessionEnded);
    }

    // Soumettre une proposition
    function submitProposal(string memory _proposal) public isWhitelisted {
        // Les électeurs inscrits sont autorisés à enregistrer leurs propositions pendant que la session d'enregistrement est active.
        require(defaultstate == WorkflowStatus.ProposalsRegistrationStarted, "La soumission de proposition n'est pas autorise a cette etape");

        Proposal memory proposal = Proposal (_proposal, 0);
        proposals.push(proposal);
        uint proposalId = proposals.length - 1;

        emit ProposalRegistered(proposalId);
    }

    function getProposals() external view returns (Proposal[] memory) {
        require(whitelist[msg.sender].isRegistered,"Vous n'etes pas autorise");
        return proposals;
    }

    // Les électeurs inscrits votent pour leur proposition préférée.
    function voter(string calldata _proposal) public isWhitelisted {
        // Possible uniquement pendant la période de vote
        require(defaultstate == WorkflowStatus.VotingSessionStarted, "Le vote n'est pas autorise en ce moment");

        // Rechercher la proposition et incrémenter le nombre de vote
        for (uint i=0;i<proposals.length;i++) {
            if(keccak256(abi.encodePacked(proposals[i].description)) == keccak256(abi.encodePacked(_proposal))) {
                proposals[i].voteCount++;
                emit Voted (msg.sender, i);
            }
        }
    }

    // L'administrateur du vote comptabilise les votes.
    function comptabilierVote() public onlyOwner returns (uint) {
        require(defaultstate == WorkflowStatus.VotingSessionEnded, "La fin du vote n'est pas possible a cette etape");
        
        defaultstate = WorkflowStatus.VotesTallied;

        emit WorkflowStatusChange(defaultstate, WorkflowStatus.VotesTallied);

        // Rechercher la proposition ayant le plus de votes
        winningProposalId = 0;
        for (uint i=1;i<proposals.length;i++) {
            if(proposals[i].voteCount > proposals[i-1].voteCount) winningProposalId=i;
        }

        return winningProposalId;
    }

    // Tout le monde peut vérifier les derniers détails de la proposition gagnante.
    // retourne le gagnant.
    function getWinner() external view returns (string memory){
        require(defaultstate == WorkflowStatus.VotesTallied, "Le vote n'est pas termine");
        return proposals[winningProposalId].description;

    }

    // Retourner le statut du workflow
    function getStatus() external view returns (WorkflowStatus) {
        return defaultstate;
    }

}