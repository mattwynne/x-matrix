# Legacy Fabro execution image for x-matrix.
#
# The active workflow now uses the devenv.nix containers."fabro-dev" image:
# ghcr.io/mattwynne/x-matrix-fabro-dev:latest. This Dockerfile is retained as
# reference only.
#
# Build once on the machine that runs Fabro's Docker sandboxes:
#
#   docker build -f .fabro/environments/x-matrix-dev-docker/Dockerfile -t x-matrix-fabro-dev:latest .
#
# The workflow then reuses this image for each run, avoiding repeated installation
# of devenv/Nix/Elixir/Node tooling in every ephemeral sandbox.

FROM ghcr.io/cachix/devenv:latest

WORKDIR /tmp/x-matrix-devenv

# Copy only the devenv inputs first so Docker can cache the expensive Nix closure
# independently from ordinary application source changes.
COPY devenv.nix devenv.lock ./

# Materialize the devenv closure, including Elixir and Node/npm from devenv.nix,
# into the image's Nix store. Later Fabro runs clone the repo into /workspace/x-matrix
# and should be able to enter the same devenv without rebuilding the language
# toolchain.
RUN devenv shell -- sh -lc 'elixir --version && node --version && npm --version && echo "x-matrix devenv closure is available"'

WORKDIR /workspace/x-matrix
