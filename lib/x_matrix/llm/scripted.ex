defmodule XMatrix.LLM.Scripted do
  @behaviour XMatrix.LLM

  @impl true
  def facilitate(:true_north, conversation, _snapshot) do
    user_content =
      conversation
      |> Enum.filter(&(&1.role == :user))
      |> List.last()
      |> case do
        nil -> nil
        %{content: content} -> String.trim(content || "")
      end

    {:ok,
     %{
       message: true_north_prompt(user_content),
       proposals: true_north_proposals(user_content),
       stage_status: :continue
     }}
  end

  def facilitate(stage, _conversation, _snapshot) do
    {:ok,
     %{
       message: prompt(stage),
       proposals: [],
       stage_status: :continue
     }}
  end

  defp true_north_prompt(nil) do
    "Let's agree your True North before anything is saved to the matrix. What direction should everything move toward?"
  end

  defp true_north_prompt("") do
    true_north_prompt(nil)
  end

  defp true_north_prompt(_content) do
    "Here are a few possible True North statements. You can send feedback for another round, or edit and submit the one that fits best."
  end

  defp true_north_proposals(nil), do: []
  defp true_north_proposals(""), do: []

  defp true_north_proposals(content) do
    base = String.trim_trailing(content, ".")

    [
      %{
        type: :true_north,
        title: base,
        description:
          "This keeps the True North close to your own words while making it explicit enough to guide later choices."
      },
      %{
        type: :true_north,
        title: "Make #{String.downcase(base)} inevitable",
        description:
          "This version adds ambition and frames the work as sustained progress toward a clear destination."
      },
      %{
        type: :true_north,
        title: "A future where #{String.downcase(base)}",
        description:
          "This version reads as a destination statement that later aspirations and tactics can support."
      }
    ]
  end

  defp prompt(:true_north) do
    true_north_prompt(nil)
  end

  defp prompt(:aspiration) do
    "Now let's name an aspiration: an ambitious outcome you are reaching for, not the work to get there."
  end

  defp prompt(:strategy) do
    "What strategy will guide your choices? Try an even over statement with genuine tension between two things you value."
  end

  defp prompt(:evidence) do
    "What evidence would tell you that your strategies are working? Name a leading indicator you could watch."
  end

  defp prompt(:tactic) do
    "What tactic or experiment will you try? Choose a concrete action that should generate the evidence you defined."
  end
end
