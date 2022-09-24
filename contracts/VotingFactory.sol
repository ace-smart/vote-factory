//SPDX-License-Identifier: Unlicense
pragma solidity >=0.7.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./Voting.sol";

contract VotingFactory is Ownable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    enum TokenType { UTILITY, NFT, GAME, REWARD, REFLECTION, DAO, MEME }
    enum PoolType { NORMAL, REFLECTION, DIVIDEND }

    struct PoolInfo {
        address pool;
        string desc;
        uint deployed;
        uint cycle;
        uint delta;
        address owner;
        bool revoked;
    }

    mapping (address => PoolInfo) public poolMap;
    EnumerableSet.AddressSet pools;

    address public teamWallet = 0x89352214a56bA80547A2842bbE21AEdD315722Ca;
    uint public cost = 0.001 ether;

    modifier onlyAdmin {
        require (hasRole(ADMIN_ROLE, msg.sender) || msg.sender == owner(), "!admin");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        grantRole(ADMIN_ROLE, msg.sender);
    }

    function poolCount() external view returns (uint) {
        return pools.length();
    }

    function deploy(
        string memory _desc,
        uint _cycleMins,
        uint _deltaMins,
        address _owner
    ) external {
        Voting pool = new Voting(_cycleMins * 1 minutes, _deltaMins * 1 minutes, cost, _owner, teamWallet);

        pools.add(address(pool));
        pool.transferOwnership(owner());

        poolMap[address(pool)] = PoolInfo({
            pool: address(pool),
            desc: _desc,
            deployed: block.timestamp,
            cycle: _cycleMins,
            delta: _deltaMins,
            owner: _owner,
            revoked: false
        });
    }

    function getPools(address _owner) external view returns (address[] memory) {
        uint count = _owner == address(0) ? pools.length() : 0;
        if (_owner != address(0)) {
            for (uint i = 0; i < pools.length(); i++) {
                if (poolMap[pools.at(i)].owner == _owner) count++;
            }
        }
        if (count == 0) return new address[](0);

        address[] memory poolList = new address[](count);
        uint index = 0;
        for (uint i = 0; i < pools.length(); i++) {
            if (_owner != address(0) && poolMap[pools.at(i)].owner != _owner) {
                continue;
            }
            poolList[index] = poolMap[pools.at(i)].pool;
            index++;
        }

        return poolList;
    }

    function revoke(address _pool, bool _flag) external onlyAdmin {
        poolMap[_pool].revoked = _flag;
    }

    function setAdmin(address _account, bool _flag) external onlyOwner {
        _flag ? grantRole(ADMIN_ROLE, _account) : revokeRole(ADMIN_ROLE, _account);
    }

    function setTeamWallet(address _wallet) external onlyOwner {
        teamWallet = _wallet;
    }

    function setCost(uint _cost) external onlyOwner {
        cost = _cost;
    }
}