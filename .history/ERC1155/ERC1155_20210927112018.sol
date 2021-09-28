// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "./utils/Address.sol";
import "./utils/Context.sol";
import "./utils/introspection/ERC165.sol";
import "./IUniswapV2Router01.sol";
import "./IUniswapV2Pair.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;
    struct UserPledge {
        bool isPledge; // 是否质押过
        // bool isWithdraw; // 是否质押取出来
        uint256 pledgeAmount; // 质押量
        uint256 blockNumber; // 质押的高度
    }
    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
    // 用户质押信息
    mapping(address => UserPledge) public userPledgeArr;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;
    address public owner;
    address public uniswapContract;
    address public pairTContract;
    uint256 gapblock = 5 * 20;
    uint256 levelDecimal = 18;
    uint256 public swapLevel1 = 10000 * 10**levelDecimal;
    uint256 public swapLevel2 = 30000 * 10**levelDecimal;
    uint256 public swapLevel3 = 50000 * 10**levelDecimal;
    uint256 public swapLevel4 = 100000 * 10**levelDecimal;
    uint256 public swapLevel5 = 1000000 * 10**levelDecimal;
    uint256 public swapLevel6 = 5000000 * 10**levelDecimal;

    uint256 public pledgeLevel1 = 300 * 10**levelDecimal;
    uint256 public pledgeLevel2 = 1000 * 10**levelDecimal;
    uint256 public pledgeLevel3 = 3000 * 10**levelDecimal;
    uint256 public pledgeLevel4 = 5000 * 10**levelDecimal;
    uint256 public pledgeLevel5 = 10000 * 10**levelDecimal;
    uint256 public pledgeLevel6 = 20000 * 10**levelDecimal;

    /**
     * @dev See {_setURI}.
     */
    constructor(
        string memory uri_,
        address uniswapContract,
        address _pairTContract
    ) {
        _setURI(uri_);
        // 批量发行
        uint256[] memory ids = [1, 2, 3, 4, 5, 6];
        uint256[] memory amounts = [15000, 12000, 8000, 1000, 200, 1];
        _mintBatch(address(this), ids, amounts, "");
        // 关联uniswap合约
        uniswapContract = _uniswapContract;
        pairTContract = _pairTContract;
        owner = msg.sender;
    }

    // 增发接口
    function increaseToken(uint256 memory id, uint256 memory amount)
        public
        returns (bool)
    {
        require(msg.sender == owner, "msg.sender != owner");
        //= [1, 2, 3, 4, 5, 6];
        // = [15000, 12000, 8000, 1000, 200, 1];
        _mint(address(this), id, amount, "");
        return true;
    }

    // 取消质押  - lp质押36天！！！！
    function withdrawLpToken() public virtual override returns (bool) {
        require(
            block.number - gapBlock > userPledgeArr[msg.sender].blockNumber,
            "wait for gapBlock"
        );
        require(userPledgeArr[msg.sender].isPledge, "isPledge need true");
        uint256 amount = userPledgeArr[msg.sender].pledgeAmount;
        userPledgeArr[msg.sender].pledgeAmount = 0;
        require(
            IUniswapV2Pair(pairTContract).transfer(msg.sender, amount),
            "withdrawNtf transferFrom failed"
        );
        return true;
    }

    // 领取徽章
    function withdrawNtf(address to, unit256 level)
        public
        view
        virtual
        override
        returns (bool)
    {
        // owner直接发放
        if (msg.sender == owner && level != 0) {
            giveNft(to, level);
        }
        /** 查询是否达到领取条件 */
        uint256 swapUsdAmount;
        uint256 pledgeUsdAmount;
        uint256 liquidity;
        (swapUsdAmount, pledgeUsdAmount, liquidity) = IUniswapV2Router01(
            uniswapContract
        ).getUserInfo(msg.sender);
        // 是否领取过了
        require(
            userPledgeArr[msg.sender].isPledge == false,
            "already collected"
        );
        // 是否达到交易量和质押量
        require(
            swapUsdAmount >= swapLevel1,
            "swapUsdAmount less than swapLevel1"
        );
        require(
            pledgeUsdAmount >= pledgeLevel1,
            "pledgeUsdAmount less than pledgeLevel1"
        );
        uint256 memory swapLevel = 0;
        uint256 memory pledgeLevel = 0;
        // 判断交易量
        if (swapUsdAmount >= swapLevel1 && swapUsdAmount < swapLevel2) {
            swapLevel = 1;
        }
        if (swapUsdAmount >= swapLevel2 && swapUsdAmount < swapLevel3) {
            swapLevel = 2;
        }
        if (swapUsdAmount >= swapLevel3 && swapUsdAmount < swapLevel4) {
            swapLevel = 3;
        }
        if (swapUsdAmount >= swapLevel4 && swapUsdAmount < swapLevel5) {
            swapLevel = 4;
        }
        if (swapUsdAmount >= swapLevel5 && swapUsdAmount < swapLevel6) {
            swapLevel = 5;
        }
        if (swapUsdAmount >= swapLevel6) {
            swapLevel = 6;
        }
        // 判断质押量
        if (pledgeUsdAmount >= pledgeLevel1 && pledgeUsdAmount < pledgeLevel2) {
            pledgeLevel = 1;
        }
        if (pledgeUsdAmount >= pledgeLevel2 && pledgeUsdAmount < pledgeLevel3) {
            pledgeLevel = 2;
        }
        if (pledgeUsdAmount >= pledgeLevel3 && pledgeUsdAmount < pledgeLevel4) {
            pledgeLevel = 3;
        }
        if (pledgeUsdAmount >= pledgeLevel4 && pledgeUsdAmount < pledgeLevel5) {
            pledgeLevel = 4;
        }
        if (pledgeUsdAmount >= pledgeLevel5 && pledgeUsdAmount < pledgeLevel6) {
            pledgeLevel = 5;
        }
        if (pledgeUsdAmount >= pledgeLevel6 && level >= 6) {
            pledgeLevel = 6;
        }
        // 得到最后的等级
        uint256 _level = swapLevel > pledgeLevel ? pledgeLevel : swapLevel;
        // 标志后续不可领了， 并记录质押量
        userPledgeArr[msg.sender].isPledge = true;
        userPledgeArr[msg.sender].pledgeAmount = pledgeUsdAmount;
        userPledgeArr[msg.sender].blockNumber = block.number;
        // 转账
        require(
            IUniswapV2Pair(pairTContract).transferFrom(
                msg.sender,
                address(this),
                liquidity
            ),
            "withdrawNtf transferFrom failed"
        );
        // 发放nft
        giveNft(to, _level);
        return true;
    }

    function giveNft(address to, uint256 id) internal virtual override {
        _safeTransferFrom(address(this), to, id, 1, "");
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC165, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id)
        public
        view
        virtual
        override
        returns (uint256)
    {
        require(
            account != address(0),
            "ERC1155: balance query for the zero address"
        );
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts and ids length mismatch"
        );

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved)
        public
        virtual
        override
    {
        require(
            _msgSender() != operator,
            "ERC1155: setting approval status for self"
        );

        _operatorApprovals[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator)
        public
        view
        virtual
        override
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            from,
            to,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        uint256 fromBalance = _balances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155: insufficient balance for transfer"
        );
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: insufficient balance for transfer"
            );
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `account`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - If `account` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(account != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            address(0),
            account,
            _asSingletonArray(id),
            _asSingletonArray(amount),
            data
        );

        _balances[id][account] += amount;
        emit TransferSingle(operator, address(0), account, id, amount);

        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            account,
            id,
            amount,
            data
        );
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            ids,
            amounts,
            data
        );
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `account`
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens of token type `id`.
     */
    function _burn(
        address account,
        uint256 id,
        uint256 amount
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(
            operator,
            account,
            address(0),
            _asSingletonArray(id),
            _asSingletonArray(amount),
            ""
        );

        uint256 accountBalance = _balances[id][account];
        require(
            accountBalance >= amount,
            "ERC1155: burn amount exceeds balance"
        );
        unchecked {
            _balances[id][account] = accountBalance - amount;
        }

        emit TransferSingle(operator, account, address(0), id, amount);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
        require(account != address(0), "ERC1155: burn from the zero address");
        require(
            ids.length == amounts.length,
            "ERC1155: ids and amounts length mismatch"
        );

        address operator = _msgSender();

        _beforeTokenTransfer(operator, account, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 accountBalance = _balances[id][account];
            require(
                accountBalance >= amount,
                "ERC1155: burn amount exceeds balance"
            );
            unchecked {
                _balances[id][account] = accountBalance - amount;
            }
        }

        emit TransferBatch(operator, account, address(0), ids, amounts);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (
                    response != IERC1155Receiver.onERC1155BatchReceived.selector
                ) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element)
        private
        pure
        returns (uint256[] memory)
    {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}
