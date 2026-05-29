defmodule XMatrix.LLM.OpenRouter do
  @behaviour XMatrix.LLM

  @endpoint "https://openrouter.ai/api/v1/chat/completions"
  @default_model "openai/gpt-oss-120b:free"
  @recent_message_limit 20

  @impl true
  def facilitate(stage, conversation, snapshot) do
    with {:ok, api_key} <- configured_api_key() do
      body = request_body(stage, conversation, snapshot)
      http_client = Application.get_env(:x_matrix, :openrouter_http_client, Req)

      case http_client.post(@endpoint,
             json: body,
             headers: [
               {"authorization", "Bearer #{api_key}"},
               {"content-type", "application/json"}
             ]
           ) do
        {:ok, %{status: status, body: response}} when status in 200..299 ->
          parse_response(response)

        {:ok, %{status: status, body: response}} ->
          {:error, {:openrouter_error, status, response}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  def request_body(stage, conversation, snapshot) do
    %{
      model: Application.get_env(:x_matrix, :openrouter_model, @default_model) || @default_model,
      messages: [
        %{role: "system", content: system_prompt(stage, snapshot)} | format_messages(conversation)
      ],
      tools: [proposal_tool()],
      tool_choice: "auto"
    }
  end

  def parse_response(%{"choices" => [%{"message" => message} | _]}) when is_map(message) do
    with {:ok, proposals} <- parse_tool_calls(Map.get(message, "tool_calls", [])) do
      {:ok,
       %{
         message:
           message
           |> Map.get("content", "")
           |> content_to_text()
           |> blank_to_default("What else would you add?"),
         proposals: proposals,
         stage_status: :continue
       }}
    end
  end

  def parse_response(_response), do: {:error, :malformed_openrouter_response}

  defp configured_api_key do
    case Application.get_env(:x_matrix, :openrouter_api_key) do
      key when is_binary(key) ->
        case String.trim(key) do
          "" -> {:error, :missing_openrouter_api_key}
          trimmed -> {:ok, trimmed}
        end

      _ ->
        {:error, :missing_openrouter_api_key}
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

  defp parse_tool_calls(nil), do: {:ok, []}
  defp parse_tool_calls([]), do: {:ok, []}

  defp parse_tool_calls(tool_calls) when is_list(tool_calls) do
    Enum.reduce_while(tool_calls, {:ok, []}, fn tool_call, {:ok, proposals} ->
      case parse_tool_call(tool_call) do
        {:ok, new_proposals} -> {:cont, {:ok, proposals ++ new_proposals}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp parse_tool_calls(_tool_calls), do: {:error, :invalid_openrouter_tool_calls}

  defp parse_tool_call(%{"function" => %{"name" => "propose_elements", "arguments" => arguments}}) do
    with {:ok, input} <- decode_arguments(arguments),
         proposals when is_list(proposals) <- Map.get(input, "proposals", []) do
      {:ok, Enum.map(proposals, &proposal_from_tool/1)}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_openrouter_tool_arguments}
    end
  end

  defp parse_tool_call(_other_tool_call), do: {:ok, []}

  defp decode_arguments(arguments) when is_binary(arguments), do: Jason.decode(arguments)
  defp decode_arguments(arguments) when is_map(arguments), do: {:ok, arguments}
  defp decode_arguments(_arguments), do: {:error, :invalid_openrouter_tool_arguments}

  defp proposal_from_tool(input) when is_map(input) do
    %{
      type: parse_type(Map.get(input, "type")),
      title: Map.get(input, "title", ""),
      description: Map.get(input, "description")
    }
  end

  defp proposal_from_tool(_input), do: %{type: :aspiration, title: "", description: nil}

  defp parse_type("true_north"), do: :true_north
  defp parse_type("aspiration"), do: :aspiration
  defp parse_type("strategy"), do: :strategy
  defp parse_type("evidence"), do: :evidence
  defp parse_type("tactic"), do: :tactic
  defp parse_type(_), do: :aspiration

  defp proposal_tool do
    %{
      type: "function",
      function: %{
        name: "propose_elements",
        description:
          "Propose X-Matrix elements for the current interview stage. The user must confirm before anything is saved.",
        parameters: %{
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

  defp content_to_text(nil), do: ""
  defp content_to_text(content) when is_binary(content), do: content

  defp content_to_text(content) when is_list(content) do
    content
    |> Enum.filter(&(Map.get(&1, "type") == "text"))
    |> Enum.map_join("\n", &Map.get(&1, "text", ""))
  end

  defp content_to_text(_content), do: ""

  defp blank_to_default(value, default) do
    case String.trim(value) do
      "" -> default
      _ -> value
    end
  end
end
