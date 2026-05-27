{ pkgs, lib, ... }:

{
  packages = with pkgs; [
    argc
    git
    just
  ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.inotify-tools ];

  languages.elixir.enable = true;
  languages.javascript.enable = true;
  languages.javascript.package = pkgs.nodejs_24;

  services.postgres = {
    enable = true;
    listen_addresses = "127.0.0.1";
    initialDatabases = [
      { name = "x_matrix_dev"; }
      { name = "x_matrix_test"; }
    ];
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
  };

  processes.phx-server.exec = "mix phx.server";

  enterShell = ''
    export PATH="$PWD/bin:$PATH"
    echo "XMatrix dev environment"
    echo "  dev setup  # install deps, create/migrate/seed DB"
    echo "  dev up     # start Postgres + Phoenix via process-compose"
    echo "  dev check  # run project checks"
  '';
}
