defmodule DeltaTest.CommitTest do
  use ExUnit.Case

  alias Delta.Commit
  import Delta.Commit

  test "Delta.Commit.resolve_conflicts/2 no conflicts with empty history or commits" do
    c = [%Commit{}]
    assert {:ok, c} == resolve_conflicts(c, [])
    assert {:ok, []} == resolve_conflicts([], c)
  end

  test "Delta.Commit.resolve_conflicts/2 no conflicts with linear ids" do
    c1 = %Commit{id: 1, previous_commit_id: 0, patch: [{:add, [:a], 0}]}
    c2 = %Commit{id: 2, previous_commit_id: 1, patch: [{:add, [:a], 1}]}
    c3 = %Commit{id: 3, previous_commit_id: 2, patch: [{:add, [:a], 2}]}
    c4 = %Commit{id: 4, previous_commit_id: 3, patch: [{:add, [:a], 3}]}

    assert {:error, _} = resolve_conflicts([c3, c2, c4], [c1])

    assert {:ok, [c2, c3, c4]} == resolve_conflicts([c2, c3, c4], [c1])
    assert {:ok, [c3, c4]} == resolve_conflicts([c3, c4], [c2, c1])
  end

  test "Delta.Commit.resolve_conflicts/2 resolves conflict on non-overlapping patches and reports unresolvable conflicts" do
    assert {:error, %Delta.Errors.Conflict{commit_id: 4, conflicts_with: 3}} =
             resolve_conflicts(
               [
                 %Commit{id: 4, previous_commit_id: 1, patch: [{:add, [:a], 3}]}
               ],
               [
                 %Commit{id: 3, previous_commit_id: 2, patch: [{:add, [:a], 2}]},
                 %Commit{id: 2, previous_commit_id: 1, patch: [{:add, [:a], 1}]},
                 %Commit{id: 1, previous_commit_id: 0, patch: [{:add, [:a], 0}]}
               ]
             )

    assert {:ok, [%Commit{id: 4, previous_commit_id: 3, patch: [{:add, [:b], 3}]}]} =
             resolve_conflicts(
               [
                 %Commit{id: 4, previous_commit_id: 1, patch: [{:add, [:b], 3}]}
               ],
               [
                 %Commit{id: 3, previous_commit_id: 2, patch: [{:add, [:a], 2}]},
                 %Commit{id: 2, previous_commit_id: 1, patch: [{:add, [:a], 1}]},
                 %Commit{id: 1, previous_commit_id: 0, patch: [{:add, [:a], 0}]}
               ]
             )
  end
end
