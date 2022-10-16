defmodule DeltaTest.CommitTest do
  use ExUnit.Case

  alias Delta.Commit
  alias Delta.Errors.Validation
  import Delta.Commit

  test "Delta.Commit.validate/1" do
    id1 = UUID.uuid4()
    id2 = UUID.uuid4()
    id3 = UUID.uuid4()

    assert {:error, %Validation{struct: Commit, field: :id}} = validate(%Commit{id: 123})

    assert {:error, %Validation{struct: Commit, field: :previous_commit_id}} =
             validate(%Commit{id: id1, previous_commit_id: 123})

    assert {:error, %Validation{struct: Commit, field: :document_id}} =
             validate(%Commit{id: id1, previous_commit_id: id2, document_id: 123})

    assert {:error, %Validation{struct: Commit, field: :patch}} =
             validate(%Commit{id: id1, previous_commit_id: id2, document_id: id3, patch: %{}})

    assert {:error, %Validation{struct: Commit, field: :previous_commit_id}} =
             validate(%Commit{id: id1, previous_commit_id: id1, document_id: id3, patch: []})

    assert {:error,
            %Validation{struct: Commit, expected: "Value to be %Elixir.Delta.Commit{}", got: 1}} =
             validate(1)

    assert {:ok, _} =
             validate(%Commit{id: id1, previous_commit_id: id2, document_id: id3, patch: []})

    assert {:ok, _} =
             validate(%Commit{id: id1, previous_commit_id: nil, document_id: id3, patch: []})
  end

  test "Delta.Commit.validate_many/1" do
    doc_id = UUID.uuid4()
    id1 = UUID.uuid4()
    id2 = UUID.uuid4()
    id3 = UUID.uuid4()

    c1 = %Commit{id: id1, document_id: doc_id, previous_commit_id: nil, patch: [{:add, ["a"], 0}]}
    c2 = %Commit{id: id2, document_id: doc_id, previous_commit_id: id1, patch: [{:add, ["a"], 1}]}
    c3 = %Commit{id: id3, document_id: doc_id, previous_commit_id: id2, patch: [{:add, ["a"], 2}]}
    c4 = %Commit{id: id1, document_id: doc_id, previous_commit_id: id3, patch: [{:add, ["a"], 0}]}
    c5 = %Commit{id: id1, document_id: id3, previous_commit_id: id3, patch: [{:add, ["a"], 0}]}

    assert {:error, _} = validate_many([c3, c2, c1])
    assert {:error, _} = validate_many([c4, c2, c3])
    assert {:error, _} = validate_many([c5, c2, c3])

    assert {:ok, []} == validate_many([])
    assert {:ok, [c1]} == validate_many([c1])
    assert {:ok, [c1, c2, c3]} == validate_many([c1, c2, c3])
  end

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

  test "Delta.Commit.do_squash/2 correctly joins two commits" do
    doc_id = UUID.uuid4()
    id1 = UUID.uuid4()
    id2 = UUID.uuid4()

    c1 = %Commit{
      id: 0,
      previous_commit_id: nil,
      document_id: :doc_id,
      order: 0,
      autosquash?: false,
      patch: [{:add, ["a"], 0}],
      reverse_patch: [{:delete, ["a"]}],
      updated_at: 0,
      meta: 0
    }

    c2 = %Commit{
      id: 1,
      document_id: :doc_id,
      previous_commit_id: nil,
      order: 1,
      autosquash?: true,
      patch: [{:add, ["b"], 1}],
      reverse_patch: [{:delete, ["b"]}],
      updated_at: 1,
      meta: 1
    }

    assert %Commit{
             id: 0,
             previous_commit_id: nil,
             document_id: :doc_id,
             order: 0,
             autosquash?: true,
             patch: [{:add, ["a"], 0}, {:add, ["b"], 1}],
             reverse_patch: [delete: ["b"], delete: ["a"]],
             meta: 1,
             updated_at: 1
           } = do_squash(c1, c2)
  end
end
