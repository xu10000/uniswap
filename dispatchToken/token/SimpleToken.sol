pragma solidity ^0.5.0;

import "../GSN/Context.sol";
import "./ERC20/ERC20.sol";
import "./ERC20/ERC20Detailed.sol";

/**
 * @title SimpleToken
 * @dev Very simple ERC20 Token example, where all tokens are pre-assigned to the creator.
 * Note they can later distribute these tokens as they wish using `transfer` and other
 * `ERC20` functions.
 */
contract SimpleToken is Context, ERC20, ERC20Detailed {

    /**
     * @dev Constructor that gives _msgSender() all of existing tokens.
     */
    constructor () public ERC20Detailed("AAB", "AAB", 18) {
        _mint(_msgSender(), 999 * 100000000 * (10 ** uint256(decimals())));
    }
    // increases()
}
