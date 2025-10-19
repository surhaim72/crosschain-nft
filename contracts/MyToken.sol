// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// https://www.openzeppelin.com/solidity-contracts#ERC721
// 定义名为 MyToken 的新合约，继承自多个 OpenZeppelin 提供的合约

contract MyToken is ERC721, ERC721Enumerable, ERC721URIStorage, ERC721Burnable, Ownable {
    
    // https://console.filebase.com

    string constant public METADATA_URI = "ipfs://QmQctgRX2iLwdRxVftCvEH3J5AePsyrru7aSmKUhTRKKj4";
    uint256 private _nextTokenId;

    // constructor(address initalOwner)
    //     ERC721("Mytoken", "MTK")
    //     Ownable(initalOwner)
    // {}

    /**
     * @dev 合约构造函数，初始化 ERC721 代币和合约所有者
     * @param tokenName 代币名称
     * @param tokenSymbol 代币符号
     */
    constructor(string memory tokenName, string memory tokenSymbol)
        ERC721(tokenName, tokenSymbol)
        Ownable(msg.sender)
    {}

    /**
     * @dev 安全铸造新的 NFT 代币
     * @param to 接收代币的地址
     * @notice 每次调用都会铸造一个新代币，tokenId 递增，使用固定的元数据 URI
     */
    function safeMint(address to) public
    {
        uint256 tokenId = _nextTokenId++;
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, METADATA_URI);
    }

    // The following functions are overrides required by Solidity.

    /**
     * @dev 内部函数，更新代币所有权状态
     * @param to 新所有者地址
     * @param tokenId 代币ID
     * @param auth 授权地址
     * @return address 返回旧所有者地址
     * @notice 重写 ERC721 和 ERC721Enumerable 的 _update 方法以确保多继承兼容性
     */
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    /**
     * @dev 内部函数，增加账户的代币余额
     * @param account 目标账户地址
     * @param value 增加的数量
     * @notice 重写 ERC721 和 ERC721Enumerable 的 _increaseBalance 方法以确保多继承兼容性
     */
    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    /**
     * @dev 获取指定代币的 URI
     * @param tokenId 代币ID
     * @return string 返回代币元数据的 URI
     * @notice 重写 ERC721 和 ERC721URIStorage 的 tokenURI 方法以确保多继承兼容性
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev 检查合约是否支持特定的接口
     * @param interfaceId 接口标识符
     * @return bool 返回是否支持该接口
     * @notice 重写多个父合约的 supportsInterface 方法以确保多继承兼容性
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}