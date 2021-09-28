pragma solidity ^0.4.2;

contract SaveFileHash3{
    
    mapping (string => bool) fileHash;
    
    function set(string hash) public returns(bool){
        fileHash[hash] = true;
        return true;
    }

    function get(string hash) public constant returns(bool){
        return fileHash[hash];
    }
}
