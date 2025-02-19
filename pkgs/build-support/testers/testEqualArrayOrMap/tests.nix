# NOTE: We must use `pkgs.runCommand` instead of `testers.runCommand` for negative tests -- those wrapped with
# `testers.testBuildFailure`. This is due to the fact that `testers.testBuildFailure` modifies the derivation such that
# it produces an output containing the exit code, logs, and other things. Since `testers.runCommand` expects the empty
# derivation, it produces a hash mismatch.
{ runCommand, testers, ... }:
let
  inherit (testers) testEqualArrayOrMap testBuildFailure;
  concatValuesArrayToActualArray = ''
    nixLog "appending all values in valuesArray to actualArray"
    for value in "''${valuesArray[@]}"; do
      actualArray+=( "$value" )
    done
  '';
  concatValuesMapToActualMap = ''
    nixLog "adding all values in valuesMap to actualMap"
    for key in "''${!valuesMap[@]}"; do
      actualMap["$key"]="''${valuesMap["$key"]}"
    done
  '';
in
{
  # NOTE: This particular test is used in the docs:
  # See https://nixos.org/manual/nixpkgs/unstable/#tester-testEqualArrayOrMap
  # or doc/build-helpers/testers.chapter.md
  docs-test-function-add-cowbell = testEqualArrayOrMap {
    name = "test-function-add-cowbell";
    valuesArray = [
      "cowbell"
      "cowbell"
    ];
    expectedArray = [
      "cowbell"
      "cowbell"
      "cowbell"
    ];
    checkSetupScript = ''
      addCowbell() {
        local -rn arrayNameRef="$1"
        arrayNameRef+=( "cowbell" )
      }

      nixLog "appending all values in valuesArray to actualArray"
      for value in "''${valuesArray[@]}"; do
        actualArray+=( "$value" )
      done

      nixLog "applying addCowbell"
      addCowbell actualArray
    '';
  };
  array-append = testEqualArrayOrMap {
    name = "testEqualArrayOrMap-array-append";
    valuesArray = [
      "apple"
      "bee"
      "cat"
    ];
    expectedArray = [
      "apple"
      "bee"
      "cat"
      "dog"
    ];
    checkSetupScript = ''
      ${concatValuesArrayToActualArray}
      actualArray+=( "dog" )
    '';
  };
  array-prepend = testEqualArrayOrMap {
    name = "testEqualArrayOrMap-array-prepend";
    valuesArray = [
      "apple"
      "bee"
      "cat"
    ];
    expectedArray = [
      "dog"
      "apple"
      "bee"
      "cat"
    ];
    checkSetupScript = ''
      actualArray+=( "dog" )
      ${concatValuesArrayToActualArray}
    '';
  };
  array-empty = testEqualArrayOrMap {
    name = "testEqualArrayOrMap-array-empty";
    valuesArray = [
      "apple"
      "bee"
      "cat"
    ];
    expectedArray = [ ];
    checkSetupScript = ''
      # doing nothing
    '';
  };
  array-missing-value =
    let
      name = "testEqualArrayOrMap-array-missing-value";
      failure = testEqualArrayOrMap {
        name = "${name}-failure";
        valuesArray = [ "apple" ];
        expectedArray = [ ];
        checkSetupScript = concatValuesArrayToActualArray;
      };
    in
    runCommand name
      {
        failed = testBuildFailure failure;
        passthru = {
          inherit failure;
        };
      }
      ''
        nixLog "Checking for exit code 1"
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        nixLog "Checking for first error message"
        grep -F \
          "ERROR: assertEqualArray: arrays differ in length: expectedArray has length 0 but actualArray has length 1" \
          "$failed/testBuildFailure.log"
        nixLog "Checking for second error message"
        grep -F \
          "ERROR: assertEqualArray: arrays differ at index 0: expectedArray has no such index but actualArray has value 'apple'" \
          "$failed/testBuildFailure.log"
        nixLog "Test passed"
        touch $out
      '';
  map-insert = testEqualArrayOrMap {
    name = "testEqualArrayOrMap-map-insert";
    valuesMap = {
      apple = "0";
      bee = "1";
      cat = "2";
    };
    expectedMap = {
      apple = "0";
      bee = "1";
      cat = "2";
      dog = "3";
    };
    checkSetupScript = ''
      ${concatValuesMapToActualMap}
      actualMap["dog"]="3"
    '';
  };
  map-remove = testEqualArrayOrMap {
    name = "testEqualArrayOrMap-map-remove";
    valuesMap = {
      apple = "0";
      bee = "1";
      cat = "2";
      dog = "3";
    };
    expectedMap = {
      apple = "0";
      cat = "2";
      dog = "3";
    };
    checkSetupScript = ''
      ${concatValuesMapToActualMap}
      unset 'actualMap[bee]'
    '';
  };
  map-missing-key =
    let
      name = "testEqualArrayOrMap-map-missing-key";
      failure = testEqualArrayOrMap {
        name = "${name}-failure";
        valuesMap = {
          bee = "1";
          cat = "2";
          dog = "3";
        };
        expectedMap = {
          apple = "0";
          bee = "1";
          cat = "2";
          dog = "3";
        };
        checkSetupScript = concatValuesMapToActualMap;
      };
    in
    runCommand name
      {
        failed = testBuildFailure failure;
        passthru = {
          inherit failure;
        };
      }
      ''
        nixLog "Checking for exit code 1"
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        nixLog "Checking for first error message"
        grep -F \
          "ERROR: assertEqualMap: maps differ in length: expectedMap has length 4 but actualMap has length 3" \
          "$failed/testBuildFailure.log"
        nixLog "Checking for second error message"
        grep -F \
          "ERROR: assertEqualMap: maps differ at key 'apple': expectedMap has value '0' but actualMap has no such key" \
          "$failed/testBuildFailure.log"
        nixLog "Test passed"
        touch $out
      '';
  map-missing-key-with-empty =
    let
      name = "map-missing-key-with-empty";
      failure = testEqualArrayOrMap {
        name = "${name}-failure";
        valuesArray = [ ];
        expectedMap.apple = 1;
        checkSetupScript = ''
          nixLog "doing nothing in checkSetupScript"
        '';
      };
    in
    runCommand name
      {
        failed = testBuildFailure failure;
        passthru = {
          inherit failure;
        };
      }
      ''
        nixLog "Checking for exit code 1"
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        nixLog "Checking for first error message"
        grep -F \
          "ERROR: assertEqualMap: maps differ in length: expectedMap has length 1 but actualMap has length 0" \
          "$failed/testBuildFailure.log"
        nixLog "Checking for second error message"
        grep -F \
          "ERROR: assertEqualMap: maps differ at key 'apple': expectedMap has value '1' but actualMap has no such key" \
          "$failed/testBuildFailure.log"
        nixLog "Test passed"
        touch $out
      '';
  map-extra-key =
    let
      name = "testEqualArrayOrMap-map-extra-key";
      failure = testEqualArrayOrMap {
        name = "${name}-failure";
        valuesMap = {
          apple = "0";
          bee = "1";
          cat = "2";
          dog = "3";
        };
        expectedMap = {
          apple = "0";
          bee = "1";
          dog = "3";
        };
        checkSetupScript = concatValuesMapToActualMap;
      };
    in
    runCommand
      {
        failed = testBuildFailure failure;
        passthru = {
          inherit failure;
        };
      }
      ''
        nixLog "Checking for exit code 1"
        (( 1 == "$(cat "$failed/testBuildFailure.exit")" ))
        nixLog "Checking for first error message"
        grep -F \
          "ERROR: assertEqualMap: maps differ in length: expectedMap has length 3 but actualMap has length 4" \
          "$failed/testBuildFailure.log"
        nixLog "Checking for second error message"
        grep -F \
          "ERROR: assertEqualMap: maps differ at key 'cat': expectedMap has no such key but actualMap has value '2'" \
          "$failed/testBuildFailure.log"
        nixLog "Test passed"
        touch $out
      '';
}
