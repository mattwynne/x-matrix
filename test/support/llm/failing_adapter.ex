defmodule XMatrix.TestLLM.FailingAdapter do
  @behaviour XMatrix.LLM

  @impl true
  def facilitate(_stage, _conversation, _snapshot), do: {:error, :provider_unavailable}
end
