
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract PredictionMarket {
    string public question;
    address public creator;
    uint256 public yesVotes;
    uint256 public noVotes;
    mapping(address => bool) public voted;

    constructor(string memory _question) {
        question = _question;
        creator = msg.sender;
    }

    function voteYes() external {
        require(!voted[msg.sender], "Already voted");
        yesVotes++;
        voted[msg.sender] = true;
    }

    function voteNo() external {
        require(!voted[msg.sender], "Already voted");
        noVotes++;
        voted[msg.sender] = true;
    }

    function getResult() external view returns (string memory) {
        if (yesVotes > noVotes) return "YES wins";
        else if (noVotes > yesVotes) return "NO wins";
        else return "TIE";
    }
}
