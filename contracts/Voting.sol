//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Voting is Ownable, Pausable {
    using SafeMath for uint256;
    using EnumerableSet for EnumerableSet.UintSet;

    uint public cycle;
    uint public delta;
    address public admin;
    address public immutable teamWallet;
    uint public cost;

    EnumerableSet.UintSet items;
    mapping(uint => mapping(uint => uint)) likeVotes;
    mapping(uint => mapping(uint => uint)) unlikeVotes;

    modifier onlyAdmin {
        require (msg.sender == owner() || msg.sender == admin, "!permission");
        _;
    }

    constructor(uint _cycle, uint _delta, uint _cost, address _admin, address _teamWallet) {
        cycle = _cycle;
        delta = _delta;
        cost = _cost;
        admin = _admin;
        teamWallet = _teamWallet;
    }

    function setCycle(uint _cycleMins, uint _deltaMins) external onlyAdmin {
        require (_cycleMins * 1 minutes > 1 hours, "!cycle");
        require (_deltaMins < _cycleMins, "!delta");

        cycle = _cycleMins * 1 minutes;
        delta = _deltaMins * 1 minutes;
    }

    function setCost(uint _cost) external onlyOwner {
        cost = _cost;
    }

    function setAdmin(address _admin) external onlyOwner {
        admin = _admin;
    }

    // 0: currentCycle, 1: previousCycle, 2: oldPreviousCycle, ...
    function getResultAll(uint prevCycleIndex) external view returns(uint[] memory, uint[] memory, uint[] memory) {
        uint[] memory itemArray = new uint[](items.length());
        uint[] memory likes = new uint[](items.length());
        uint[] memory unlikes = new uint[](items.length());

        uint _cycle = block.timestamp.div(cycle).mul(cycle).sub(cycle * prevCycleIndex).add(delta);

        for (uint i = 0; i < items.length(); i++) {
            itemArray[i] = items.at(i);
            likes[i] = likeVotes[_cycle][items.at(i)];
            unlikes[i] = unlikeVotes[_cycle][items.at(i)];
        }

        return (itemArray, likes, unlikes);
    }

    function getResult(uint _item, uint prevCycleIndex) external view returns(uint, uint) {
        if (items.contains(_item) == false) return (0, 0);

        uint _cycle = block.timestamp.div(cycle).mul(cycle).sub(cycle * prevCycleIndex).add(delta);
        return (likeVotes[_cycle][_item], unlikeVotes[_cycle][_item]);
    }

    function vote(uint _item, bool isUnlike) external payable whenNotPaused {
        if (cost > 0) require (msg.value >= cost);

        uint currentCycle = block.timestamp.div(cycle).mul(cycle).add(delta);
        if (isUnlike) unlikeVotes[currentCycle][_item] ++;
        else likeVotes[currentCycle][_item] ++;

        if (address(this).balance > 0) {
            // payable(teamWallet).transfer(address(this).balance);
            payable(teamWallet).call{
                value: address(this).balance,
                gas: 30000
            }("");
        }

        if (!items.contains(_item)) items.add(_item);
    }
}