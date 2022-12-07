# See LICENSE for licensing information.

defmodule JopLog do
  alias :ets, as: ETS
  require JL.Valid
  @tag_start "joplog_start"

  @moduledoc """
  Documentation for JopLog an in memory log

  ## Example

  iex> :mylog
  ...> |> JopLog.init()
  ...> |> JopLog.log("device_1", data: 112)
  ...> |> JopLog.log("device_2", data: 113)
  ...> |> JopLog.flush()

  """

  defstruct [:ets]
  @type t :: %__MODULE__{ets: ETS.t()}

  @doc """
  Initialize JopLog with an ets table.
  returns a %Joplog{}
  """
  @spec init(joplog_name: String.t()) :: JopLog.t()
  def init(joplog_name) when is_binary(joplog_name) do
    tab = String.to_atom(joplog_name)

    JL.Valid.ets? tab do
      JopLog.ref(joplog_name)
      |> reset()
    end

    ETS.new(tab, [:bag, :named_table, :public])

    joplog = JopLog.ref(joplog_name)

    IO.puts("JopLog now logging on memory joplog #{joplog.ets}.")
    log(joplog, @tag_start, "#{JL.Common.date_str()}")
  end

  @doc """
  returns a reference, in case the JopLog Struct
  returned by init/1 is used by different processes
  """
  @spec ref(joplog_name :: String.t()) :: JopLog.t()
  def ref(joplog_name) when is_binary(joplog_name) do
    tab = String.to_atom(joplog_name)

    JL.Valid.ets?(tab, do: %JopLog{ets: tab}, else: throw(:uninitialized))
  end

  @doc """
  log in `%JopLog{}` key and value
  returns the updated `%JopLog{}`.
  """
  @spec log(JopLog.t(), any, any) :: JopLog.t()
  def log(%JopLog{ets: tab} = jop, key, value) do
    JL.Valid.ets?(tab, do: ETS.insert(tab, {key, value, now_μs()}))
    jop
  end

  @doc """
  write a joplog on disk.
  2 logs are generated : dates.gz and keys.gz
  unless option :notstop is used, logging is stopped.
  """
  @spec flush(JopLog.t(), opt :: atom) :: JopLog.t()
  def flush(%JopLog{ets: tab} = joplog, opt \\ nil) do
    JL.Valid.ets? tab do
      {logs, t0} =
        case lookup_tag_start(tab) do
          nil ->
            {[], 0}

          t0 ->
            {ETS.tab2list(tab), t0}
        end

      if opt == :nostop do
        IO.puts(
          "JopLog continue logging.\nflushing memory joplog #{tab} (#{Enum.count(joplog)} records) on files ..."
        )

        clear(joplog)
      else
        IO.puts(
          "JopLog logging stopped.\nflushing memory joplog #{tab} (#{Enum.count(joplog)} records) on files ..."
        )

        reset(joplog)
      end

      JL.Writer.flush(tab, t0, logs)
    end

    joplog
  end

  defp reset(%JopLog{ets: tab}),
    do: JL.Valid.ets?(tab, do: ETS.delete(tab))

  defp lookup_tag_start(tab) do
    case ETS.lookup(tab, @tag_start) do
      [{_, _, t0}] ->
        t0

      [] ->
        nil
    end
  end

  @doc """
  erase all entries
  """
  @spec clear(JopLog.t()) :: JopLog.t()
  def clear(%JopLog{ets: tab} = joplog) do
    JL.Valid.ets? tab do
      t0 = lookup_tag_start(tab)
      ETS.delete_all_objects(tab)

      if t0 do
        ETS.insert(tab, {@tag_start, t0, now_μs()})
      end
    end

    joplog
  end

  defp now_μs(), do: System.monotonic_time(:microsecond)

  @doc """
  returns if the %JopLog{} is initialized with an ets table
  """
  def is_initialized(%JopLog{ets: ets}),
    do: JL.Valid.ets?(ets, do: true, else: false)

  defimpl Enumerable do
    @doc """
    returns the size of the ets table
    """
    def count(%JopLog{ets: ets}) do
      {:ok, max(0, ETS.info(ets, :size) - 1)}
    end

    @doc """
    returns if `key`is member of the %JopLog{}
    """
    @spec member?(JopLog.t(), any) :: {:ok, boolean}
    def member?(%JopLog{ets: ets}, key) do
      {:ok, ETS.member(ets, key)}
    end

    def reduce(%JopLog{ets: ets}, acc, fun) do
      ETS.tab2list(ets)
      |> List.keysort(2)
      |> Enum.drop(1)
      |> Enum.map(fn {k, v, _t} -> {k, v} end)
      |> Enumerable.List.reduce(acc, fun)
    end

    def slice(_id) do
      {:error, __MODULE__}
    end
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%JopLog{ets: tab} = jop, opts) do
      JL.Valid.ets? tab do
        concat(["#JopLog<#{tab}:size(", to_doc(Enum.count(jop), opts), ")>"])
      else
        concat(["#JopLog<#{tab}:uninitialized>"])
      end
    end
  end
end
