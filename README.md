# XMatrix

To start your Phoenix server with the project dev environment:

* Run `direnv allow` once so `devenv` loads automatically.
* Run `dev setup` to install dependencies, create/migrate/seed the databases, and build assets.
* Run `dev up` to start Postgres and Phoenix via process-compose. It uses strict ports, so stop any other Postgres on port 5432 first.

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Useful commands:

* `dev server` starts Phoenix only, assuming Postgres is already running.
* `dev check` runs the project quality gate in test mode.
* `dev test` runs tests.
* `dev psql` opens `psql` against `x_matrix_dev`.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix
