defmodule XMatrix.LLM.OpenRouterTest do
  use ExUnit.Case, async: false

  alias XMatrix.LLM.OpenRouter

  defmodule FakeHTTP do
    def post(endpoint, opts) do
      test_pid = Application.fetch_env!(:x_matrix, :openrouter_test_pid)
      send(test_pid, {:openrouter_request, endpoint, opts})

      {:ok,
       %{
         status: 200,
         body: %{"choices" => [%{"message" => %{"content" => "Tell me more."}}]}
       }}
    end
  end

  setup do
    previous_key = Application.get_env(:x_matrix, :openrouter_api_key)
    previous_model = Application.get_env(:x_matrix, :openrouter_model)
    previous_http_client = Application.get_env(:x_matrix, :openrouter_http_client)
    previous_test_pid = Application.get_env(:x_matrix, :openrouter_test_pid)

    Application.put_env(:x_matrix, :openrouter_api_key, "test-key")
    Application.put_env(:x_matrix, :openrouter_http_client, FakeHTTP)
    Application.put_env(:x_matrix, :openrouter_test_pid, self())

    on_exit(fn ->
      restore_env(:openrouter_api_key, previous_key)
      restore_env(:openrouter_model, previous_model)
      restore_env(:openrouter_http_client, previous_http_client)
      restore_env(:openrouter_test_pid, previous_test_pid)
    end)
  end

  test "uses the default free OpenRouter model when no model is configured" do
    Application.delete_env(:x_matrix, :openrouter_model)

    assert {:ok, %{message: "Tell me more.", proposals: [], stage_status: :continue}} =
             OpenRouter.facilitate(:aspiration, [%{role: :user, content: "Hello"}], %{})

    assert_receive {:openrouter_request, "https://openrouter.ai/api/v1/chat/completions", opts}
    assert opts[:json].model == "openai/gpt-oss-120b:free"
  end

  test "uses the configured OpenRouter model" do
    Application.put_env(:x_matrix, :openrouter_model, "openrouter/test-model")

    assert {:ok, _reply} = OpenRouter.facilitate(:aspiration, [], %{})

    assert_receive {:openrouter_request, _endpoint, opts}
    assert opts[:json].model == "openrouter/test-model"
  end

  test "parses assistant text responses" do
    response = %{
      "choices" => [
        %{"message" => %{"content" => "What outcome matters most?"}}
      ]
    }

    assert OpenRouter.parse_response(response) ==
             {:ok,
              %{
                message: "What outcome matters most?",
                proposals: [],
                stage_status: :continue
              }}
  end

  test "parses propose_elements tool calls" do
    response = %{
      "choices" => [
        %{
          "message" => %{
            "content" => "Here are candidates.",
            "tool_calls" => [
              %{
                "function" => %{
                  "name" => "propose_elements",
                  "arguments" =>
                    Jason.encode!(%{
                      proposals: [
                        %{
                          type: "strategy",
                          title: "Focus partnerships even over direct delivery",
                          description: "Use others' reach."
                        },
                        %{type: "unknown", title: "Fallback type"}
                      ]
                    })
                }
              }
            ]
          }
        }
      ]
    }

    assert {:ok, reply} = OpenRouter.parse_response(response)

    assert reply.proposals == [
             %{
               type: :strategy,
               title: "Focus partnerships even over direct delivery",
               description: "Use others' reach."
             },
             %{type: :aspiration, title: "Fallback type", description: nil}
           ]
  end

  test "returns an error when tool call arguments are malformed JSON" do
    response = %{
      "choices" => [
        %{
          "message" => %{
            "content" => "Here are candidates.",
            "tool_calls" => [
              %{"function" => %{"name" => "propose_elements", "arguments" => "{"}}
            ]
          }
        }
      ]
    }

    assert {:error, %Jason.DecodeError{}} = OpenRouter.parse_response(response)
  end

  defp restore_env(key, nil), do: Application.delete_env(:x_matrix, key)
  defp restore_env(key, value), do: Application.put_env(:x_matrix, key, value)
end
