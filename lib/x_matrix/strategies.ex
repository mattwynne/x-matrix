defmodule XMatrix.Strategies do
  @moduledoc """
  Strategy context for read-only X-Matrix data.
  """

  import Ecto.Query

  alias XMatrix.Repo

  alias XMatrix.Strategies.{
    Strategy,
    StrategyCorrelation,
    StrategyElement,
    StrategyMessage,
    StrategySectionSession
  }

  @doc "Load any strategy with elements (ordered) and correlations preloaded."
  def get_strategy!(id) do
    Strategy
    |> Repo.get!(id)
    |> preload_ordered()
  end

  def get_seeded_strategy! do
    Strategy
    |> order_by([s], asc: s.inserted_at, asc: s.id)
    |> limit(1)
    |> Repo.one!()
    |> then(&get_strategy!(&1.id))
  end

  @doc "List completed strategies, most recently worked on first."
  def list_strategies do
    Strategy
    |> where([s], s.status == :complete)
    |> order_by([s], desc: s.updated_at, desc: s.id)
    |> Repo.all()
  end

  defp preload_ordered(strategy) do
    Repo.preload(
      strategy,
      [
        elements: from(e in StrategyElement, order_by: [asc: e.position, asc: e.id]),
        correlations:
          from(c in StrategyCorrelation,
            order_by: [asc: c.id],
            preload: [:source_element, :target_element]
          )
      ],
      force: true
    )
  end

  def create_draft_strategy(attrs) do
    %Strategy{}
    |> Strategy.changeset(Map.merge(%{status: :draft, current_step: "true_north"}, attrs))
    |> Repo.insert()
  end

  def update_strategy(%Strategy{} = strategy, attrs) do
    with :ok <- ensure_draft(strategy) do
      strategy |> Strategy.changeset(attrs) |> Repo.update()
    end
  end

  def set_step(%Strategy{} = strategy, step) when is_binary(step) do
    with :ok <- ensure_draft(strategy) do
      strategy |> Strategy.changeset(%{current_step: step}) |> Repo.update()
    end
  end

  def complete_strategy(%Strategy{} = strategy) do
    strategy |> Strategy.changeset(%{status: :complete, current_step: "review"}) |> Repo.update()
  end

  def get_resumable_draft do
    Strategy
    |> where([s], s.status == :draft)
    |> order_by([s], desc: s.updated_at, desc: s.id)
    |> limit(1)
    |> Repo.one()
  end

  def get_section_session(%Strategy{} = strategy, section) when section in [:true_north] do
    StrategySectionSession
    |> Repo.get_by(strategy_id: strategy.id, section: section)
    |> case do
      nil -> create_section_session(strategy, section)
      session -> session
    end
  end

  def update_section_session(%Strategy{} = strategy, section, state)
      when section in [:true_north] do
    with :ok <- ensure_draft(strategy) do
      strategy
      |> get_section_session(section)
      |> StrategySectionSession.changeset(%{state: normalize_session_state(state)})
      |> Repo.update()
    end
  end

  def update_section_session(%StrategySectionSession{} = session, state) do
    with :ok <- ensure_draft(session) do
      session
      |> StrategySectionSession.changeset(%{state: normalize_session_state(state)})
      |> Repo.update()
    end
  end

  def submit_true_north(%Strategy{} = strategy, attrs) do
    with :ok <- ensure_draft(strategy) do
      title =
        attrs |> Map.get(:title, Map.get(attrs, "title", "")) |> to_string() |> String.trim()

      description =
        attrs
        |> Map.get(:description, Map.get(attrs, "description", ""))
        |> to_string()
        |> String.trim()

      existing =
        StrategyElement
        |> where([e], e.strategy_id == ^strategy.id and e.element_type == :true_north)
        |> order_by([e], asc: e.position, asc: e.id)
        |> limit(1)
        |> Repo.one()

      result =
        case existing do
          nil ->
            add_element(strategy, %{
              element_type: :true_north,
              title: title,
              description: description
            })

          element ->
            update_element(element, %{title: title, description: description})
        end

      with {:ok, element} <- result,
           {:ok, session} <- mark_true_north_submitted(strategy, title, description),
           {:ok, updated_strategy} <- set_step(strategy, "true_north_agreed") do
        {:ok, %{element: element, session: session, strategy: updated_strategy}}
      end
    end
  end

  def add_element(%Strategy{} = strategy, attrs) do
    with :ok <- ensure_draft(strategy) do
      next_position =
        StrategyElement
        |> where([e], e.strategy_id == ^strategy.id)
        |> select([e], count(e.id))
        |> Repo.one()
        |> Kernel.+(1)

      %StrategyElement{}
      |> StrategyElement.changeset(
        attrs
        |> Map.put(:strategy_id, strategy.id)
        |> Map.put(:position, next_position)
      )
      |> Repo.insert()
    end
  end

  def update_element(%StrategyElement{} = element, attrs) do
    with :ok <- ensure_draft(element) do
      element |> StrategyElement.changeset(attrs) |> Repo.update()
    end
  end

  def delete_element(%StrategyElement{} = element) do
    with :ok <- ensure_draft(element) do
      Repo.delete(element)
    end
  end

  @doc "Set (or clear, when strength is :none) the correlation for a source→target pair."
  def upsert_correlation(%Strategy{} = strategy, source, target, strength) do
    with :ok <- ensure_draft(strategy) do
      existing =
        StrategyCorrelation
        |> Repo.get_by(
          strategy_id: strategy.id,
          source_element_id: source.id,
          target_element_id: target.id
        )

      cond do
        strength == :none and is_nil(existing) ->
          {:ok, nil}

        strength == :none ->
          Repo.delete(existing)

        true ->
          (existing || %StrategyCorrelation{})
          |> StrategyCorrelation.changeset(%{
            strategy_id: strategy.id,
            source_element_id: source.id,
            target_element_id: target.id,
            strength: strength
          })
          |> Repo.insert_or_update()
      end
    end
  end

  def add_message(%Strategy{} = strategy, role, content) when role in [:assistant, :user] do
    with :ok <- ensure_draft(strategy) do
      %StrategyMessage{}
      |> StrategyMessage.changeset(%{strategy_id: strategy.id, role: role, content: content})
      |> Repo.insert()
    end
  end

  def list_messages(%Strategy{} = strategy) do
    StrategyMessage
    |> where([m], m.strategy_id == ^strategy.id)
    |> order_by([m], asc: m.inserted_at, asc: m.id)
    |> Repo.all()
  end

  def elements_by_type(%Strategy{} = strategy, element_type) do
    Enum.filter(strategy.elements, &(&1.element_type == element_type))
  end

  defp ensure_draft(%Strategy{status: :draft}), do: :ok
  defp ensure_draft(%Strategy{}), do: {:error, :strategy_complete}

  defp ensure_draft(%StrategyElement{} = element) do
    element.strategy_id
    |> get_strategy!()
    |> ensure_draft()
  end

  defp ensure_draft(%StrategySectionSession{} = session) do
    session.strategy_id
    |> get_strategy!()
    |> ensure_draft()
  end

  defp create_section_session(%Strategy{} = strategy, section) do
    %StrategySectionSession{}
    |> StrategySectionSession.changeset(%{
      strategy_id: strategy.id,
      section: section,
      state: default_section_state(section)
    })
    |> Repo.insert!()
  end

  defp default_section_state(:true_north) do
    %{
      "messages" => [],
      "candidates" => [],
      "status" => "in_progress"
    }
  end

  defp normalize_session_state(state) when is_map(state) do
    state
    |> stringify_keys()
    |> Map.put_new("messages", [])
    |> Map.put_new("candidates", [])
    |> Map.put_new("status", "in_progress")
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {to_string(key), stringify_value(value)} end)
  end

  defp stringify_value(value) when is_map(value), do: stringify_keys(value)
  defp stringify_value(value) when is_list(value), do: Enum.map(value, &stringify_value/1)
  defp stringify_value(value), do: value

  defp mark_true_north_submitted(strategy, title, description) do
    session = get_section_session(strategy, :true_north)

    state =
      session.state
      |> normalize_session_state()
      |> Map.put("status", "submitted")
      |> Map.put("submitted", %{"title" => title, "description" => description})

    update_section_session(session, state)
  end
end
