defmodule Delta.Commit.CacheLayer do
  @moduledoc """
  Caching layer for Delta.Commit
  """

  require Logger
  use GenServer

  alias Delta.DataLayer
  alias Delta.Commit
  alias Delta.Errors.{DoesNotExist, AlreadyExist, Conflict}

  @behaviour DataLayer
  @behaviour Delta.Commit

  defstruct [:document_id, :table, :persistent_layer, continuations: []]

  @impl DataLayer
  @doc """
  Starts this DataLayer with specific document id.

  Has no options.
  """
  def start_link(document_id, _ \\ nil) do
    table = document_id_to_table(document_id)

    GenServer.start_link(
      __MODULE__,
      %__MODULE__{document_id: document_id, table: table}
    )
  end

  @impl DataLayer
  @doc """
  Returns anonyumous function /0, which deletes mnesia table used by the layer.
  """
  def crash_handler(%{table: t}) do
    fn ->
      :mnesia.delete_table(t)
    end
  end

  @impl Commit
  @doc """
  Lists all commits on this data layer.

  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/1`
  """
  def list({__MODULE__, document_id}, false) do
    table = document_id_to_table(document_id)

    {status, result} = :mnesia.transaction(list_transaction(table))
    {status, result, nil}
  end

  def list({__MODULE__, document_id}, true) do
    table = document_id_to_table(document_id)

    {status, result} = :mnesia.transaction(list_transaction(table))

    {status, result,
     fn {mod, ^document_id} = l ->
       with {:atomic, r, c} <- mod.list(l, false), do: {:atomic, join_lists(r, result), c}
     end}
  end

  def list(layer_id, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> list(continuation?)

  @impl Commit
  @doc """
  Lists commits from one to another.

  Continuation lists data on another data layer with priority to this data layer.

  See `Delta.Commit.list/2`
  """
  def list({__MODULE__, document_id}, from, to, false) do
    table = document_id_to_table(document_id)

    from_id = Commit.id(from)
    to_id = Commit.id(to)

    {status, result} = :mnesia.transaction(list_transaction(table, from_id, to_id))

    {status, result, nil}
  end

  def list({__MODULE__, document_id}, from, to, true) do
    table = document_id_to_table(document_id)

    from_id = Commit.id(from)
    to_id = Commit.id(to)

    with {:atomic, result} <- :mnesia.transaction(list_transaction(table, from_id, to_id)) do
      continuation =
        case {List.last(result), to_id} do
          {%{id: id}, id} ->
            nil

          {nil, _} ->
            fn {mod, ^document_id} = l -> mod.list(l, from_id, to_id, false) end

          {%{id: from_id}, to_id} ->
            fn {mod, ^document_id} = l ->
              with {:atomic, r, c} <- mod.list(l, from_id, to_id, false),
                   do: {:atomic, join_lists(r, result), c}
            end
        end

      {:atomic, result, continuation}
    else
      {status, result} -> {status, result, fn {mod, ^document_id} = l -> mod.list(l, from_id, to_id, false) end}
    end
  end

  def list(layer_id, from, to, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> list(from, to, continuation?)

  @impl Commit
  @doc """
  Gets commit.

  If it exists, continuation is alwayus `nil`

  See `Delta.Commit.get/1`
  """
  def get({__MODULE__, document_id}, id, false) do
    table = document_id_to_table(document_id)
    id = Commit.id(id)

    {status, result} = :mnesia.transaction(get_transaction(table, id))
    {status, result, nil}
  end

  def get({__MODULE__, document_id}, id, true) do
    table = document_id_to_table(document_id)
    id = Commit.id(id)

    case :mnesia.transaction(get_transaction(table, id)) do
      {:atomic, result} ->
        {:atomic, result, nil}

      {status, result} ->
        {status, result, fn {mod, ^document_id} = l -> mod.get(l, id, false) end}
    end
  end

  def get(layer_id, id, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> get(id, continuation?)

  @impl Commit
  @doc """
  Writes commit.

  Continuation wirtes commit on another data layer.

  See `Delta.Commit.write/1`
  """
  def write(
        {__MODULE__, document_id} = layer_id,
        %Commit{document_id: document_id} = commit,
        continuation?
      ) do
    commit = struct(commit, updated_at: Delta.Datetime.now!())

    with {:atomic, result} <- :mnesia.transaction(write_transaction(commit)) do
      continuation = fn {mod, ^document_id} = l -> mod.write(l, result, false) end
      add_continuation(layer_id, continuation)

      {:atomic, result, if(continuation?, do: continuation, else: nil)}
    else
      {status, result} -> {status, result, nil}
    end
  end

  def write(layer_id, commit, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> write(commit, continuation?)

  @impl Commit
  @doc """
  Writes a list of commits. Commits are assumed to have equal `document_id`.

  Continuation writes commits on another data layer

  See `Delta.Commit.write_many/1`
  """
  def write_many(
        {__MODULE__, document_id} = layer_id,
        [%Commit{document_id: document_id} | _] = commits,
        continuation?
      ) do
    with {:atomic, result} <- :mnesia.transaction(write_many_transaction(commits)) do
      continuation = fn {mod, ^document_id} = l -> mod.write_many(l, result, false) end
      add_continuation(layer_id, continuation)

      {:atomic, result, if(continuation?, do: continuation, else: nil)}
    else
      {status, result} -> {status, result, nil}
    end
  end

  def write_many(_, [], _), do: {:atomic, [], nil}

  def write_many(layer_id, commits, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> write_many(commits, continuation?)

  @impl Commit
  @doc """
  Deletes commit. Always successful. Continuation deletes commit on antother data layer.

  See `Delta.Commit.delete/1`
  """
  def delete({__MODULE__, document_id} = layer_id, id, continuation?) do
    table = document_id_to_table(document_id)
    id = Commit.id(id)

    continuation = fn {mod, ^document_id} = l -> mod.delete(l, id, false) end

    {status, result} = :mnesia.transaction(fn -> delete_transaction(table, id) end)
    add_continuation(layer_id, continuation)
    {status, result, if(continuation?, do: continuation, else: nil)}
  end

  def delete(layer_id, commit, continuation?),
    do: layer_id |> DataLayer.layer_id_normal() |> delete(commit, continuation?)

  # def add_commits(
  #       {__MODULE__, document_id} = layer_id,
  #       commits,
  #       continuation?
  #     ) do
  #   now = Delta.Datetime.now()
  #   commits = Enum.map(commits, &struct(&1, updated_at: now))

  #   case :mnesia.transaction(add_commits_transaction(document_id, commits)) do
  #     {:atomic, result} ->
  #       continuation = fn {mod, ^document_id} = layer_id -> mod.write_many(layer_id, commits, false) end
  #       add_continuation(layer_id, continuation)

  #       {:atomic, result, if(continuation?, do: continuation, else: nil)}

  #     {:aborted, {:continuation, list_continuation}} ->

  #       {:aborted, :continue, fn {mod, ^document_id} = layer_id ->
  #         history = list_continuation.(layer_id)
  #         mod.add_commits(layer_id, commits, history, false)
  #       end}

  #     {status, result} ->
  #       {status, result, nil}
  #   end
  # end

  # defp add_commits_transaction(_, _, []), do: fn -> [] end

  # defp add_commits_transaction(document_id, commits) do
  #   table = document_id_to_table(document_id)
  #   [%{previous_commit_id: %{id: previous_id}} | _] = commits = Enum.map(commits, &to_record/1)

  #   fn ->
  #     latest_id =
  #       case :mnesia.last(table) do
  #         :"$end_of_table" -> :"$end_of_table"
  #         order -> hd(:mnesia.read(order))
  #       end

  #     case {previous_id, latest_id} do
  #       {nil, :"$end_of_table"} ->
  #         write_many_transaction(table, commits)

  #       {id, id} ->
  #         write_many_transaction(table, commits)

  #       {to_id, latest_id} ->
  #         case list({__MODULE__, document_id}, latest_id, to_id, true) do
  #           {:atomic, history, nil} ->
  #             add_commits_transaction_try_resolve_conflict(table, commits, history)

  #           {:atomic, _, continuation} ->
  #             :mnesia.abort({:conitnue, continuation})
  #         end
  #     end
  #   end
  # end

  # defp add_commits_transaction_try_resolve_conflict(
  #        table,
  #        [%{id: first_id, delta: first_patch} = first | rest],
  #        [%{id: conflict_id, previous_commit_id: new_pcid} | _] = history
  #      ) do
  #   unless Enum.any?(history, fn %{delta: patch} ->
  #            Delta.Json.Patch.overlap?(first_patch, patch)
  #          end) do
  #     add_commits_transaction_no_conflict(table, [
  #       struct(first, previous_commit_id: new_pcid) | rest
  #     ])
  #   else
  #     :mnesia.abort(%Conflict{commit_id: first_id, conflicts_with: conflict_id})
  #   end
  # end

  @impl GenServer
  def init(%{document_id: id, table: table} = state) do
    Swarm.register_name({__MODULE__, id}, self())
    Swarm.join(DataLayer, self())

    DataLayer.CrashHandler.add(self(), crash_handler(state))

    with {:atomic, _} <-
           :mnesia.create_table(table,
             attributes: [
               :order,
               :id,
               :previous_commit_id,
               :document_id,
               :autosquash?,
               :delta,
               :reverse_delta,
               :meta,
               :updated_at
             ],
             index: [:id, :previous_commit_id, :autosquash?],
             type: :ordered_set,
             disc_copies: [node()]
           ) do
      {:ok, state}
    else
      {:aborted, reason} -> {:error, reason}
      reason -> {:error, reason}
    end
  end

  @impl GenServer
  def handle_cast({:add_continuation, continuation}, %{continuations: cs} = state),
    do: {:noreply, struct(state, continuations: [continuation | cs])}

  defp list_transaction(table) do
    fn ->
      :mnesia.foldl(
        fn rec, acc -> [from_record(rec) | acc] end,
        [],
        table
      )
    end
  end

  defp list_transaction(table, from_id, to_id) do
    fn ->
      from1 = :mnesia.index_read(table, from_id, 3)
      to1 = :mnesia.index_read(table, to_id, 3)

      from2 = if from1 == [], do: :mnesia.last(table), else: elem(hd(from1), 1)
      to2 = if to1 == [], do: :mnesia.first(table), else: elem(hd(to1), 1)

      from = max(from2, to2)
      to = min(from2, to2)

      if from != :"$end_of_table" and to != :"$end_of_table" do
        from..to//-1
        |> Enum.flat_map(&:mnesia.read(table, &1))
        |> Enum.map(&from_record/1)
      else
        []
      end
    end
  end

  defp get_transaction(table, id) do
    fn ->
      case :mnesia.index_read(table, id, 3) do
        [r] -> from_record(r)
        [] -> :mnesia.abort(%DoesNotExist{struct: Commit, id: id})
      end
    end
  end

  defp write_transaction(commit) do
    fn ->
      commit
      |> to_record()
      |> :mnesia.write()

      commit
    end
  end

  defp write_many_transaction(commits) do
    fn ->
      commits
      |> Enum.map(&:mnesia.write(to_record(&1)))

      commits
    end
  end

  defp delete_transaction(table, id) do
    fn ->
      case :mnesia.index_read(table, id, 3) do
        [r] -> :mnesia.delete_object(r)
        _ -> :ok
      end
    end
  end

  defp add_continuation(layer_id, continuation),
    do: layer_id |> DataLayer.layer_id_pid() |> GenServer.cast({:add_continuation, continuation})

  defp from_record(
         {_, order, id, previous_commit_id, document_id, autosquash?, delta, reverse_delta, meta,
          updated_at}
       ) do
    %Commit{
      id: id,
      previous_commit_id: previous_commit_id,
      document_id: document_id,
      order: order,
      autosquash?: autosquash?,
      delta: delta,
      reverse_delta: reverse_delta,
      meta: meta,
      updated_at: updated_at
    }
  end

  defp to_record(%Commit{
         id: id,
         previous_commit_id: previous_commit_id,
         document_id: document_id,
         order: order,
         autosquash?: autosquash?,
         delta: delta,
         reverse_delta: reverse_delta,
         meta: meta,
         updated_at: updated_at
       }) do
    {document_id_to_table(document_id), order, id, previous_commit_id, document_id, autosquash?,
     delta, reverse_delta, meta, updated_at}
  end

  defp document_id_to_table(id), do: :"#{__MODULE__}.#{id}"

  defp into_map(l), do: l |> Enum.map(&{&1.order, &1}) |> Enum.into(%{})

  defp join_lists(a, b) do
    a = into_map(a)
    b = into_map(b)

    Map.merge(a, b)
    |> Enum.sort_by(&elem(&1, 0), :desc)
    |> Enum.map(&elem(&1, 1))
  end
end
