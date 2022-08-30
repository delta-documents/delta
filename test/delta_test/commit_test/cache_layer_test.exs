defmodule DeltaTest.CommitTest.CacheLayerTest do
  use ExUnit.Case

  alias Delta.Commit
  alias Delta.Commit.CacheLayer

  setup do
    {:ok, _} = Delta.Commit.CacheLayer.start_link(1)
    on_exit(fn -> :mnesia.delete_table(:"Elixir.Delta.Commit.CacheLayer.1") end)

    :ok
  end

  defmodule TestLayer do
    def list(_, _) do
      {:atomic, [], nil}
    end

    def list(_, _, _, _) do
      {:atomic, [], nil}
    end

    def get(_, _, _) do
      {:aborted, nil, nil}
    end

    def write(_, data, _) do
      {:atomic, data, nil}
    end

    def delete(_, data, _) do
      {:atomic, data, nil}
    end
  end

  @commit %Commit{
    id: 1,
    previous_commit_id: nil,
    document_id: 1,
    order: 0,
    autosquash?: false,
    delta: [],
    reverse_delta: nil,
    meta: nil
  }

  @layer_id {CacheLayer, 1}
  @test_layer_id {TestLayer, 1}

  test "Delta.Commit.CacheLayer.list/2" do
    assert {:atomic, [], nil} = CacheLayer.list(@layer_id, false)
    assert {:atomic, [], continuation} = CacheLayer.list(@layer_id, true)
    assert {:atomic, [], _} = continuation.(@test_layer_id)

    assert {:atomic, _, _} = CacheLayer.write(@layer_id, @commit, false)

    assert {:atomic, [%Commit{id: 1}], continuation} = CacheLayer.list(@layer_id, true)
    assert {:atomic, [%Commit{id: 1}], _} = continuation.(@test_layer_id)
  end

  test "Delta.Commit.CacheLayer.list/4" do
    assert {:atomic, [], nil} = CacheLayer.list(@layer_id, nil, nil, false)
    assert {:atomic, [], continuation} = CacheLayer.list(@layer_id, nil, nil, true)
    assert {:atomic, [], _} = continuation.(@test_layer_id)

    assert {:atomic, _, _} = CacheLayer.write(@layer_id, @commit, false)


    assert {:atomic, [%Commit{id: 1}], nil} = CacheLayer.list(@layer_id, nil, nil, false)
    assert {:atomic, [%Commit{id: 1}], nil} = CacheLayer.list(@layer_id, 1, 1, true)
    assert {:atomic, [%Commit{id: 1}], continuation} = CacheLayer.list(@layer_id, 0, 10, true)
    assert {:atomic, [%Commit{id: 1}], _} = continuation.(@test_layer_id)
  end

  test "Delta.Commit.CacheLayer.get/3" do
    assert {:aborted, _, nil} = CacheLayer.get(@layer_id, @commit, false)
    assert {:aborted, _, nil} = CacheLayer.get(@layer_id, @commit.id, false)
    assert {:aborted, _, continuation} = CacheLayer.get(@layer_id, @commit.id, true)

    assert {:aborted, nil, nil} = continuation.(@test_layer_id)

    assert {:atomic, _, _} = CacheLayer.write(@layer_id, @commit, false)

    assert {:atomic, %Commit{id: 1}, nil} = CacheLayer.get(@layer_id, @commit.id, false)
    assert {:atomic, %Commit{id: 1}, nil} = CacheLayer.get(@layer_id, @commit.id, true)
  end

  test "Delta.Commit.CacheLayer.write/3" do
    assert {:atomic, %Commit{id: 1}, nil} = CacheLayer.write(@layer_id, @commit, false)
    assert {:atomic, %Commit{id: 1}, continuation} = CacheLayer.write(@layer_id, @commit, true)
    assert {:atomic, %Commit{id: 1}, _} = continuation.(@test_layer_id)
  end

  test "Delta.Commit.delete/3" do
    assert {:atomic, %Commit{id: 1}, nil} = CacheLayer.write(@layer_id, @commit, false)
    assert {:atomic, _, nil} = CacheLayer.delete(@layer_id, @commit, false)
    assert {:atomic, _, continuation} = CacheLayer.delete(@layer_id, @commit, true)
    assert {:atomic, 1, _} = continuation.(@test_layer_id)
  end
end
