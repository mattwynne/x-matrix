defmodule XMatrix.TestLLM.ProposingAdapter do
  @behaviour XMatrix.LLM

  @impl true
  def facilitate(stage, _conversation, _snapshot) do
    {:ok,
     %{
       message: "I have a suggestion.",
       proposals: [%{type: stage, title: "Suggested item", description: "Suggested why"}],
       stage_status: :continue
     }}
  end
end
