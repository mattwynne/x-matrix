defmodule XMatrixWeb.HomeLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:strategies, Strategies.list_strategies())
     |> assign(:draft, Strategies.get_resumable_draft())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl">
        <h1 class="text-3xl font-bold text-slate-950">X-Matrix</h1>
        <p class="mt-3 text-slate-600">
          Build a strategy through a guided interview, in Karl Scotland's
          X-Matrix facilitation order — True North, Aspirations, Strategies,
          Evidence, then Tactics, testing how they relate along the way.
        </p>

        <div class="mt-8 flex flex-col gap-3 sm:flex-row">
          <.link
            navigate={~p"/interview"}
            class="rounded-xl bg-indigo-700 px-5 py-3 text-center font-semibold text-white hover:bg-indigo-800"
          >
            Start a new strategy
          </.link>

          <.link
            :if={@draft}
            navigate={~p"/interview/#{@draft.id}"}
            class="rounded-xl border border-indigo-300 px-5 py-3 text-center font-medium text-indigo-700 hover:bg-indigo-50"
          >
            Resume interview
          </.link>
        </div>

        <section class="mt-10">
          <h2 class="text-sm font-semibold uppercase tracking-wide text-slate-500">
            Your strategies
          </h2>

          <p :if={@strategies == []} class="mt-3 text-slate-500">
            No finished strategies yet. Start a new one above to build your first X-Matrix.
          </p>

          <ul class="mt-3 space-y-2">
            <li :for={strategy <- @strategies}>
              <.link
                navigate={~p"/strategies/#{strategy.id}"}
                class="block rounded-xl border border-slate-200 px-5 py-4 hover:border-indigo-300 hover:bg-slate-50"
              >
                <span class="font-semibold text-slate-900">{strategy.title}</span>
                <span :if={strategy.description} class="mt-1 block text-sm text-slate-500">
                  {strategy.description}
                </span>
              </.link>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
