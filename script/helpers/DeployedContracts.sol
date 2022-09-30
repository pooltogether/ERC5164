// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.16;

import { Script } from "forge-std/Script.sol";
import { stdJson } from "forge-std/StdJson.sol";
import "solidity-stringutils/strings.sol";

import { CrossChainRelayerOptimism } from "../../src/relayers/CrossChainRelayerOptimism.sol";
import { CrossChainExecutorOptimism } from "../../src/executors/CrossChainExecutorOptimism.sol";

import { CrossChainRelayerPolygon } from "../../src/relayers/CrossChainRelayerPolygon.sol";
import { CrossChainExecutorPolygon } from "../../src/executors/CrossChainExecutorPolygon.sol";

import { Greeter } from "../../test/Greeter.sol";

string constant OP_GOERLI_PATH = "/broadcast/DeployToOptimismGoerli.s.sol/420/";
string constant MUMBAI_PATH = "/broadcast/DeployToMumbai.s.sol/80001/";

abstract contract DeployedContracts is Script {
  using strings for *;
  using stdJson for string;

  /* ============ Helpers ============ */

  function _getDeploymentArtifacts(string memory _deploymentArtifactsPath)
    internal
    returns (string[] memory)
  {
    string[] memory inputs = new string[](5);
    inputs[0] = "ls";
    inputs[1] = "-m";
    inputs[2] = "-x";
    inputs[3] = "-r";
    inputs[4] = string.concat(vm.projectRoot(), _deploymentArtifactsPath);
    bytes memory res = vm.ffi(inputs);

    // Slice ls result, remove newline and push into array
    strings.slice memory s = string(res).toSlice();
    strings.slice memory delim = ", ".toSlice();
    strings.slice memory sliceNewline = "\n".toSlice();
    string[] memory filesName = new string[](s.count(delim) + 1);

    for (uint256 i = 0; i < filesName.length; i++) {
      filesName[i] = s.split(delim).beyond(sliceNewline).toString();
    }

    return filesName;
  }

  function _getContractAddress(
    string memory _contractName,
    string memory _artifactsPath,
    string memory _errorMsg
  ) internal returns (address) {
    string[] memory filesName = _getDeploymentArtifacts(_artifactsPath);

    uint256 filesNameLength = filesName.length;

    // Loop through deployment artifacts and find latest deployed `_contractName` address
    for (uint256 j; j < filesNameLength; j++) {
      string memory filePath = string.concat(vm.projectRoot(), _artifactsPath, filesName[j]);
      string memory jsonFile = vm.readFile(filePath);
      string memory contractName = abi.decode(
        stdJson.parseRaw(jsonFile, ".transactions[0].contractName"),
        (string)
      );

      if (
        keccak256(abi.encodePacked((contractName))) == keccak256(abi.encodePacked((_contractName)))
      ) {
        return
          abi.decode(stdJson.parseRaw(jsonFile, ".transactions[0].contractAddress"), (address));
      }
    }

    revert(_errorMsg);
  }

  /* ============ Getters ============ */

  /* ============ Optimism ============ */
  function _getCrossChainRelayerOptimism() internal returns (CrossChainRelayerOptimism) {
    return
      CrossChainRelayerOptimism(
        _getContractAddress(
          "CrossChainRelayerOptimism",
          "/broadcast/DeployToOptimismGoerli.s.sol/5/",
          "relayer-not-found"
        )
      );
  }

  function _getCrossChainExecutorOptimism() internal returns (CrossChainExecutorOptimism) {
    return
      CrossChainExecutorOptimism(
        _getContractAddress("CrossChainExecutorOptimism", OP_GOERLI_PATH, "executor-not-found")
      );
  }

  function _getGreeterOptimism() internal returns (Greeter) {
    return Greeter(_getContractAddress("Greeter", OP_GOERLI_PATH, "greeter-not-found"));
  }

  /* ============ Polygon ============ */
  function _getCrossChainRelayerPolygon() internal returns (CrossChainRelayerPolygon) {
    return
      CrossChainRelayerPolygon(
        _getContractAddress(
          "CrossChainRelayerPolygon",
          "/broadcast/DeployToMumbai.s.sol/5/",
          "relayer-not-found"
        )
      );
  }

  function _getCrossChainExecutorPolygon() internal returns (CrossChainExecutorPolygon) {
    return
      CrossChainExecutorPolygon(
        _getContractAddress("CrossChainExecutorPolygon", MUMBAI_PATH, "executor-not-found")
      );
  }

  function _getGreeterPolygon() internal returns (Greeter) {
    return Greeter(_getContractAddress("Greeter", MUMBAI_PATH, "greeter-not-found"));
  }
}
