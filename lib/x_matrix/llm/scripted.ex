defmodule XMatrix.LLM.Scripted do
  @behaviour XMatrix.LLM

  @impl true
  def facilitate(stage, _conversation, _snapshot) do
    {:ok,
     %{
       message: prompt(stage),
       proposals: [],
       stage_status: :continue
     }}
  end

  defp prompt(:true_north) do
    "Let's start with your True North. In one sentence, what direction should everything move toward?"
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
