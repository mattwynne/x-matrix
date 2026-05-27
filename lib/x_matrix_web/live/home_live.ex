defmodule XMatrixWeb.HomeLive do
  use XMatrixWeb, :live_view

  alias XMatrix.Strategies

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:example, Strategies.get_seeded_strategy!())
     |> assign(:draft, Strategies.get_resumable_draft())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="mx-auto max-w-2xl p-8 text-center">
        <h1 class="text-3xl font-bold text-slate-950">X-Matrix</h1>
        <p class="mt-3 text-slate-600">
          Build a strategy through a guided interview, in the X-Matrix facilitation order.
        </p>

        <div class="mt-8 flex flex-col gap-3">
          <.link
            navigate={~p"/strategies/#{@example.id}"}
            class="rounded-xl border border-slate-300 px-5 py-3 font-medium text-slate-800 hover:bg-slate-50"
          >
            View example matrix
          </.link>

          <.link
            navigate={~p"/interview"}
            class="rounded-xl bg-indigo-700 px-5 py-3 font-semibold text-white hover:bg-indigo-800"
          >
            Start interview
          </.link>

          <.link
            :if={@draft}
            navigate={~p"/interview/#{@draft.id}"}
            class="rounded-xl border border-indigo-300 px-5 py-3 font-medium text-indigo-700 hover:bg-indigo-50"
          >
            Resume interview
          </.link>
        </div>
      </main>
    </Layouts.app>
    """
  end
end
