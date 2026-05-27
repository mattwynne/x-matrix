defmodule XMatrix.LLM.ScriptedTest do
  use ExUnit.Case, async: true

  alias XMatrix.LLM.Scripted

  test "facilitates each element stage with deterministic prompts" do
    for stage <- [:true_north, :aspiration, :strategy, :evidence, :tactic] do
      assert {:ok, reply} = Scripted.facilitate(stage, [], %{})
      assert is_binary(reply.message)
      assert reply.message != ""
      assert reply.proposals == []
      assert reply.stage_status in [:continue, :ready_to_advance]
    end
  end

  test "true north prompt names True North" do
    assert {:ok, reply} = Scripted.facilitate(:true_north, [], %{})
    assert reply.message =~ "True North"
  end

  test "strategy prompt teaches even over phrasing" do
    assert {:ok, reply} = Scripted.facilitate(:strategy, [], %{})
    assert reply.message =~ "even over"
  end
end
