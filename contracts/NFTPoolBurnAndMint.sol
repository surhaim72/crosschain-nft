// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IRouterClient} from "@chainlink/contracts-ccip/contracts/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/contracts/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/contracts/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/token/ERC20/utils/SafeERC20.sol";
import {WrappedNFT} from "./WrappedNFT.sol";

/**
 * 这是一个示例合约，使用硬编码值以提高清晰度。
 * 这是一个使用未经审计代码的示例合约。
 * 在生产环境中使用此代码。
 */

// 一个用于跨链发送/接收字符串数据的简单消息合约。
contract NFTPoolBurnAndMint is CCIPReceiver, OwnerIsCreator {
    using SafeERC20 for IERC20;

    /**自定义错误说明**/ 
    // 用于确保合约有足够的余额。
    error NotEnoughBalance(uint256 currentBalance, uint256 calculatedFees); 
    // 当尝试提取Ether但没有可提取金额时使用。
    error NothingToWithdraw(); 
    // 当Ether提取失败时使用。
    error FailedToWithdrawEth(address owner, address target, uint256 value); 
    // 当接收者地址为0时使用。
    error InvalidReceiverAddress(); 

    /**
     * 当消息发送到另一条链时触发的事件。
     * @param messageId 唯一标识此跨链消息的ID。
     * @param destinationChainSelector 目标链的链选择器。
     * @param receiver 目标链的接收者的地址。
     * @param text 发送的字节数据。
     * @param feeToken 用于支付CCIP费用的代币地址。
     * @param fees 发送CCIP消息所支付的费用。
     **/
    event MessageSent(
        bytes32 indexed messageId, 
        uint64 indexed destinationChainSelector, 
        address receiver, 
        bytes text, 
        address feeToken, 
        uint256 fees 
    );

    /**
     * @dev 创建NFT的代币ID。
     * @param tokenId 创建的代币ID。
     * @param newOwner 代币的新拥有者。
     **/
    event tokenMinted(
        uint256 tokenId, 
        address newOwner
    );

    // 存储最近一次接收到的跨链消息的唯一标识符
    bytes32 private s_lastReceivedMessageId; 
    // 存储最近一次接收到的跨链消息的文本数据
    string private s_lastReceivedText; 
    // LINK 代币合约的接口，用于支付跨链消息的费用
    IERC20 private s_linkToken;
    // 自定义 NFT 合约的实例
    WrappedNFT public wnft;

   
    /**
     * @param _router CCIP Router 合约地址，用于跨链通信。
     * @param _link LINK 代币地址，用于支付跨链费用。
     * @param ntfAddr 自定义 NFT 合约地址。
     */
    constructor(address _router, address _link,address ntfAddr) CCIPReceiver(_router) {
        s_linkToken = IERC20(_link);
        wnft = WrappedNFT(ntfAddr);
    }

    // 通过lockAndSendNFT函数发送我们所需要知道的数据，被锁定的pool NFT
    // 包含tokenId和newOwner
    struct RequestData {
        uint256 tokenId;
        address newOwner;   
    }
     // 记得为变量添加可见性
    mapping(uint256 => bool) public tokenLocked;

    
    /**
     * @dev 修饰符用于检查接收者地址不为0。
     * @param _receiver 接收者地址。
     */
    modifier validateReceiver(address _receiver) {
        if (_receiver == address(0)) revert InvalidReceiverAddress();
        _;
    }

    // 通过burnAndSendNFT函数发送我们所需要知道的数据，被锁定的pool
    function burnAndSendNFT(
        uint256 tokentId,
        address newOwner,
        uint64 chainSelector,
        address receiver) public returns (bytes32){
        //将 NFT 转移到该地址以锁定 NFT
        // msg.sender 发送人 、address(this) 接收地址 、tokentId 发送人ID
        wnft.transferFrom(msg.sender, address(this), tokentId);

        // 操作什么？
        // 锁定 NFT后，立即燃烧它
        wnft.burn(tokentId);

        // 合约数据区发送
        bytes memory payload = abi.encode(tokentId, newOwner);
        // 向目标链上的接收者发送数据。
        bytes32 messagId = sendMessagePayLINK(chainSelector,receiver,payload);
        return messagId;
    }


    /// @notice 向目标链上的接收者发送数据。
    /// @notice 使用 LINK 代币支付费用。
    /// @dev 假设您的合约拥有足够的 LINK 代币。
    /// @param _destinationChainSelector 目标区块链的标识符（也称为选择器）。
    /// @param _receiver 目标区块链上接收者的地址。
    /// @param _text 要发送的文本。
    /// @return messageId 发送的 CCIP 消息的 ID。
    function sendMessagePayLINK(
        uint64 _destinationChainSelector,
        address _receiver,
        bytes memory _text
    )
        internal
        returns (bytes32 messageId)
    {
        
        // 在内存中创建一个 EVM2AnyMessage 结构体，包含发送跨链消息所需的信息
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(
            _receiver,
            _text,
            address(s_linkToken)
        );

        // 初始化路由器客户端实例以与跨链路由器交互
        IRouterClient router = IRouterClient(this.getRouter());

        // 获取发送CCIP消息所需的费用
        uint256 fees = router.getFee(_destinationChainSelector, evm2AnyMessage);

        if (fees > s_linkToken.balanceOf(address(this)))
            revert NotEnoughBalance(s_linkToken.balanceOf(address(this)), fees);

        // 批准路由器代表合约转移LINK代币。它将使用LINK支付费用
        s_linkToken.approve(address(router), fees);

        // 通过路由器发送CCIP消息并存储返回的CCIP消息ID
        messageId = router.ccipSend(_destinationChainSelector, evm2AnyMessage);

        // 触发一个包含消息详情的事件
        emit MessageSent(
            messageId,                    // 跨链消息的唯一标识符
            _destinationChainSelector,    // 目标链的选择器（链标识符）
            _receiver,                    // 目标链上接收者的地址
            _text,                        // 发送的字节数据内容
            address(s_linkToken),         // 用于支付CCIP费用的代币地址（LINK代币地址）
            fees                          // 发送CCIP消息所支付的费用金额
        );
        // 返回CCIP消息ID
        return messageId;
    }


    // 处理接收到的消息
    function _ccipReceive(
        Client.Any2EVMMessage memory any2EvmMessage
    )
        internal
        override
    {
        // 做了什么操作：
        // 解码接收到的跨链消息数据，将其转换为RequestData结构体
        RequestData memory requestData = abi.decode((any2EvmMessage.data),(RequestData));
        // 从解码后的数据中提取tokenId
        uint256 tokenId = requestData.tokenId;
        // 从解码后的数据中提取新的所有者地址
        address newOwner = requestData.newOwner; 
        // 调用WNFT合约的mintWithSpecificTokenId方法为新所有者铸造指定tokenId的NFT
        wnft.mintWithSpecificTokenId(newOwner, tokenId);

        emit tokenMinted(tokenId, newOwner);

       
    }

        /// @notice 构造一个CCIP消息。
        /// @dev 此函数将创建一个EVM2AnyMessage结构体，其中包含发送文本所需的所有信息。
        /// @param _receiver 接收者的地址。
        /// @param _data 要发送的字节数据。
        /// @param _feeTokenAddress 用于支付费用的代币地址。设置为address(0)表示使用原生代币支付gas费用。
        /// @return Client.EVM2AnyMessage 返回一个包含发送CCIP消息所需信息的EVM2AnyMessage结构体。
    function _buildCCIPMessage(
        address _receiver,
        bytes memory _data,
        address _feeTokenAddress
        ) private pure returns (Client.EVM2AnyMessage memory) {
            return Client.EVM2AnyMessage({
                receiver: abi.encode(_receiver),
                data: _data,
                tokenAmounts: new Client.EVMTokenAmount[](0),
                extraArgs: Client._argsToBytes(
                    Client.EVMExtraArgsV1({
                        gasLimit: 200_000
                    })
                ),
                feeToken: _feeTokenAddress
            });
        }

    /// @notice 获取最后接收消息的详细信息。
    /// @return messageId 最后接收消息的ID。
    /// @return text 最后接收的文本。
    function getLastReceivedMessageDetails()
        external
        view
        returns (bytes32 messageId, string memory text)
    {
        return (s_lastReceivedMessageId, s_lastReceivedText);
    }

    /// @notice 回退函数，允许合约接收以太币。
    /// @dev 此函数没有函数体，使其成为接收以太币的默认函数。
    /// 当向合约发送不带任何数据的以太币时，会自动调用此函数。
    receive() external payable {}

    /// @notice 允许合约所有者从合约中提取全部以太币余额。
    /// @dev 如果没有资金可提取或转账失败，此函数会回退。
    /// 应该只能由合约所有者调用。
    /// @param _beneficiary 以太币应发送到的地址。
    function withdraw(address _beneficiary) public onlyOwner {
        // 获取此合约的余额
        uint256 amount = address(this).balance;

        // 如果没有可提取的资金则回退
        if (amount == 0) revert NothingToWithdraw();

        // 尝试发送资金，捕获成功状态并丢弃任何返回数据
        (bool sent, ) = _beneficiary.call{value: amount}("");

        // 如果发送失败，回退并提供有关尝试转账的信息
        if (!sent) revert FailedToWithdrawEth(msg.sender, _beneficiary, amount);
    }

    /// @notice 允许合约所有者提取特定ERC20代币的所有代币。
    /// @dev 如果没有代币可提取，此函数会以'NothingToWithdraw'错误回退。
    /// @param _beneficiary 代币将发送到的地址。
    /// @param _token 要提取的ERC20代币的合约地址。
    function withdrawToken(
        address _beneficiary,
        address _token
    ) public onlyOwner {
        // 获取此合约的余额
        uint256 amount = IERC20(_token).balanceOf(address(this));

        // 如果没有可提取的资金则回退
        if (amount == 0) revert NothingToWithdraw();

        IERC20(_token).safeTransfer(_beneficiary, amount);
    }
}
