pragma solidity ^0.4.2;

contract SaveFileHash2{
    
    mapping (bytes32 => bool) fileHash;
    
    function set(bytes32 hash) public returns(bool){
        bytes32 index = sha256(this, hash);
        fileHash[index] = true;
        return true;
    }

    function get(bytes32 hash) public constant returns(bool){
        bytes32 index = sha256(this, hash);
        return fileHash[index];
    }
}
