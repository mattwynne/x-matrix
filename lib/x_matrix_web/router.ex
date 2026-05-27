defmodule XMatrixWeb.Router do
  use XMatrixWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {XMatrixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", XMatrixWeb do
    pipe_through :browser

    live "/", XMatrixLive, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", XMatrixWeb do
  #   pipe_through :api
  # end
end
