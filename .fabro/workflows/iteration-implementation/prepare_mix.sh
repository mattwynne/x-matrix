#!/usr/bin/env bash
set -euo pipefail

cd /workspace

devenv shell -- bash -lc '
  set -euo pipefail
  if [ "$HOME" = "/env" ] || [ ! -d "$HOME" ] || [ ! -w "$HOME" ]; then
    export HOME=/tmp/home
  fi
  export MIX_HOME="${MIX_HOME:-$HOME/.mix}"
  export HEX_HOME="${HEX_HOME:-$HOME/.hex}"
  export HEX_CACERTS_PATH="${HEX_CACERTS_PATH:-${SSL_CERT_FILE:-${NIX_SSL_CERT_FILE:-}}}"
  mkdir -p "$HOME" "$MIX_HOME" "$HEX_HOME"
  mix local.hex --force
  mix local.rebar --force
  mix deps.get
'
