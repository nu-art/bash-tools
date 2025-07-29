#!/bin/bash

source "${MAIN_SOURCE_FOLDER}/index.sh"

test_string_endsWith_success() {
  expect "$(string.endsWith "hello-world" "world")" to.equal "true"
}

test_string_startsWith_success() {
  expect "$(string.startsWith "hello-world" "hello")" to.equal "true"
}

test_string_substring_basic() {
  expect "$(string.substring "abcdef" 1 3)" to.equal "bcd"
}

test_string_contains_success() {
  expect "$(string.contains "foobar" "oba")" to.equal "true"
}

test_string_replace_once() {
  expect "$(string.replace foo bar "foo baz foo")" to.equal "bar baz foo"
}

test_string_replace_all() {
  expect "$(string.replaceAll foo bar "foo baz foo")" to.equal "bar baz bar"
}

test_string_join_with_dash() {
  expect "$(string.join - a b c)" to.equal "a-b-c"
}

test_string_find_full_match() {
  expect "$(string.find '[0-9]{4}' 'release-2024-stable')" to.equal "2024"
}

test_string_find_with_group() {
  expect "$(string.find 'version ([0-9]{2}\.[0-9]{1})' 'app version 22.5 released')" to.equal "22.5"
}

test_string_find_no_match_returns_empty() {
  expect "$(string.find 'unicorn' 'there is a cat')" to.be.empty
}

test_string_find_nested_group_first_only() {
  expect "$(string.find 'v([0-9]+\.[0-9]+)' 'v1.2.3')" to.equal "1.2"
}

test_string_find_alphanumeric() {
  expect "$(string.find 'ID: ([A-Z0-9]+)' 'user info ID: A1B2C3 ok')" to.equal "A1B2C3"
}
