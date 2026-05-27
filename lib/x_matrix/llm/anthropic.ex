defmodule XMatrix.LLM.Anthropic do
  @behaviour XMatrix.LLM

  @endpoint "https://api.anthropic.com/v1/messages"
  @recent_message_limit 20

  @impl true
  def facilitate(stage, conversation, snapshot) do
    api_key = Application.get_env(:x_matrix, :anthropic_api_key)
    model = Application.get_env(:x_matrix, :anthropic_model, "claude-3-5-haiku-latest")

    body = %{
      model: model,
      max_tokens: 800,
      system: system_prompt(stage, snapshot),
      messages: format_messages(conversation),
      tools: [proposal_tool()]
    }

    case Req.post(@endpoint,
           json: body,
           headers: [
             {"x-api-key", api_key || ""},
             {"anthropic-version", "2023-06-01"},
             {"content-type", "application/json"}
           ]
         ) do
      {:ok, %{status: status, body: response}} when status in 200..299 ->
        {:ok, parse_response(response)}

      {:ok, %{status: status, body: response}} ->
        {:error, {:anthropic_error, status, response}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_messages(conversation) do
    conversation
    |> Enum.drop_while(&(&1.role == :assistant))
    |> Enum.take(-@recent_message_limit)
    |> Enum.map(fn %{role: role, content: content} ->
      %{role: to_string(role), content: content}
    end)
  end

  defp parse_response(response) do
    content = Map.get(response, "content", [])

    message =
      content
      |> Enum.filter(&(Map.get(&1, "type") == "text"))
      |> Enum.map_join("\n", &Map.get(&1, "text", ""))
      |> blank_to_default("What else would you add?")

    proposals =
      content
      |> Enum.filter(
        &(Map.get(&1, "type") == "tool_use" and Map.get(&1, "name") == "propose_elements")
      )
      |> Enum.flat_map(fn block ->
        block
        |> Map.get("input", %{})
        |> Map.get("proposals", [])
        |> Enum.map(&proposal_from_tool/1)
      end)

    %{message: message, proposals: proposals, stage_status: :continue}
  end

  defp proposal_from_tool(input) do
    %{
      type: parse_type(Map.get(input, "type")),
      title: Map.get(input, "title", ""),
      description: Map.get(input, "description")
    }
  end

  defp parse_type("true_north"), do: :true_north
  defp parse_type("aspiration"), do: :aspiration
  defp parse_type("strategy"), do: :strategy
  defp parse_type("evidence"), do: :evidence
  defp parse_type("tactic"), do: :tactic
  defp parse_type(_), do: :aspiration

  defp proposal_tool do
    %{
      name: "propose_elements",
      description:
        "Propose X-Matrix elements for the current interview stage. The user must confirm before anything is saved.",
      input_schema: %{
        type: "object",
        properties: %{
          proposals: %{
            type: "array",
            items: %{
              type: "object",
              properties: %{
                type: %{
                  type: "string",
                  enum: ["true_north", "aspiration", "strategy", "evidence", "tactic"]
                },
                title: %{type: "string"},
                description: %{type: ["string", "null"]}
              },
              required: ["type", "title"]
            }
          }
        },
        required: ["proposals"]
      }
    }
  end

  defp system_prompt(:strategy, snapshot) do
    """
    You are facilitating an X-Matrix strategy interview. The current stage is Strategies.
    Help the user write strategy statements as genuine 'even over' choices: both sides must be valuable and in tension.
    Never claim anything has been saved. Use the propose_elements tool for candidate strategy items.

    Confirmed matrix snapshot:
    #{inspect(snapshot)}
    """
  end

  defp system_prompt(stage, snapshot) do
    """
    You are facilitating an X-Matrix strategy interview. The current stage is #{stage}.
    Ask one helpful question at a time. You may propose candidate elements with the propose_elements tool.
    Never claim anything has been saved; the user must explicitly add suggestions.

    Confirmed matrix snapshot:
    #{inspect(snapshot)}
    """
  end

  defp blank_to_default("", default), do: default
  defp blank_to_default(value, _default), do: value
end
