pragma solidity ^0.4.20;

/**
 * @title 文件哈希存证管理合约
 * @author gushui
 * @dev 针对大文件的存证，可以计算文件的哈希然后在合约链上存证，大文件保存在传统的云存储，
 * 待验证文件时使用合约链上的文件哈希记录校验。当前合约按照用户维度统计存证的文件哈希，可通过用户、文件哈希、交易哈希查询存在的文件。
 */

contract NotaryManager {
    int8 SUCCESS = 0;
    int8 FILE_NOT_EXIST = -1;
    int8 FILE_ALREADY_EXIST = -2;
    int8 USER_NOT_EXIST = -3;

    struct File {
        bytes hash;
        uint uploadTime;
        identity owner;
    }

    struct User {
        identity id;
        uint count;
        mapping(bytes => File) fileMap;
    }

    /// @dev 文件hash对应的文件存证实体，实际可选用
    mapping(bytes => File) fileNotaryMap;

    /// @dev 交易hash对应的文件存证实体，实际可选用
    mapping(identity => File) txHashToFileNotaryMap;

    mapping(identity => User) userMap;

    identity[] userList;

    /// @dev 存证文件hash的方法，构造File结构，按照用户，文件hash，交易hash维度保存数据，实际根据情况选择
    function saveFile(bytes fileHash) public returns(int8 code) {
        User storage user = userMap[msg.sender];

        if (user.id == 0x0) { // 如果不存在
            user.id = msg.sender;
            userList.push(msg.sender);
        }

        File storage file = user.fileMap[fileHash]; // 检查文件是否已经存在，这里无需再检查fileNotaryMap
        if(file.hash.length != 0){
            return FILE_ALREADY_EXIST;
        }

        // 用户维度的存储和统计
        user.count += 1;
        file.hash = fileHash;
        file.uploadTime = block.timestamp; // 使用区块的时间戳
        file.owner = msg.sender;
        user.fileMap[fileHash] = file;

        // 文件维度的存储
        fileNotaryMap[fileHash] = file;

        // 交易维度的存储
        txHashToFileNotaryMap[tx.txhash] = file;

        return SUCCESS;
    }

    /// @dev 使用存证文件hash来查询存证记录
    function queryFileByHash(bytes fileHash) public view returns(int8 code, bytes fHash, uint fUpLoadTime, identity owner) {
        File storage file = fileNotaryMap[fileHash];
        if(file.hash.length == 0){
            return (FILE_NOT_EXIST, "", 0, 0);
        }

        return(SUCCESS, file.hash, file.uploadTime, file.owner);
    }

    /// @dev 使用存证交易的hash来查询文件存证记录
    function queryFileByTXHash(identity txHash) public view returns(int8 code, bytes fHash, uint fUpLoadTime, identity owner) {
        File storage file = txHashToFileNotaryMap[txHash];
        if(file.hash.length == 0){
            return (FILE_NOT_EXIST, "", 0, 0);
        }

        return(SUCCESS, file.hash, file.uploadTime, file.owner);
    }

    /// @dev 使用存证文件的hash来查询文件存证记录，并检查是当前sender是文件的owner
    function queryOwnedFile(bytes fileHash) public view returns(int8 code, bytes fHash, uint fUpLoadTime, identity owner) {
        User storage user = userMap[msg.sender];
        if (user.id == 0x0) {
            return (USER_NOT_EXIST, "", 0, msg.sender);
        }
        File memory file = user.fileMap[fileHash];
        if(file.hash.length == 0){
            return (FILE_NOT_EXIST, "", 0, msg.sender);
        }

        return(SUCCESS, file.hash, file.uploadTime, file.owner);
    }

    /// @dev 获取文件存证的用户列表
    function getUserList() public view returns(identity[] users) {
        return userList;
    }

    /// @dev 获取指定用户拥有的文件数量
    function getUserFiles(identity userId) public view returns(int8 code, uint count) {
        User storage user = userMap[userId];
        if (user.id == 0x0) {
            return (USER_NOT_EXIST, 0);
        }
        return (SUCCESS, user.count);
    }
}
