defmodule XMatrix.LLM do
  @type message :: %{role: :assistant | :user, content: String.t()}
  @type proposal :: %{type: atom(), title: String.t(), description: String.t() | nil}
  @type reply :: %{
          message: String.t(),
          proposals: [proposal()],
          stage_status: :continue | :ready_to_advance
        }

  @callback facilitate(stage :: atom(), conversation :: [message()], snapshot :: map()) ::
              {:ok, reply()} | {:error, term()}
end
