#!/bin/bash

isMacOS() {
  if [[ "$(uname -v)" =~ "Darwin" ]]; then echo "true"; else echo; fi
}
