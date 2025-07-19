#!/bin/bash

test_echo_to_equal_success() {
  expect.run "echo hello" to.equal "hello"
}

test_expect_fail_with_output() {
  expect.run "expect.run 'echo hello' to.equal 'world'" to.fail.with 1 "expected: 'world'"
}

test_to_contain_fail() {
  expect.run "expect 'abc' to.contain 'xyz'" to.fail.with 1 "expected to contain: 'xyz'"
}

test_to_match_fail() {
  expect.run "expect 'abc' to.match '[0-9]+'" to.fail.with 1 "expected to match regex: '[0-9]+'"
}

test_to_be_empty_fail() {
  expect.run "expect 'non-empty' to.be.empty" to.fail.with 1 "empty value"
}

# to.exit.with
test_to_exit_with_success_zero() {
  expect.run "true" to.exit.with 0
}

test_to_exit_with_success_nonzero() {
  expect.run "bash -c 'exit 7'" to.exit.with 7
}

test_to_exit_with_fail() {
  expect.run "false" to.exit.with 1
}

# to.return (alias of to.exit.with)
test_to_return_success() {
  expect.run "bash -c 'exit 42'" to.return 42
}

test_to_return_fail() {
  expect.run "expect.run \"bash -c 'exit 2'\" to.return 3" to.fail.with 1
}
