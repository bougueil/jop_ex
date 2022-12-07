# See LICENSE for licensing information.

defmodule IfValidEts do
  @moduledoc false

  defmacro ets(tab, clauses) do
    valid_if(tab, clauses)
  end

  defp valid_if(tab, do: do_clause) do
    valid_if(tab, do: do_clause, else: nil)
  end

  defp valid_if(tab, do: do_clause, else: else_clause) do
    quote do
      case :undefined != :ets.info(unquote(tab), :size) do
        x when :"Elixir.Kernel".in(x, [false, nil]) -> unquote(else_clause)
        _ -> unquote(do_clause)
      end
    end
  end
end

defmodule JopLog do
  alias :ets, as: ETS
  require IfValidEts
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

    IfValidEts.ets tab do
      JopLog.ref(joplog_name)
      |> reset()
    end

    ETS.new(tab, [:bag, :named_table, :public])

    joplog = JopLog.ref(joplog_name)

    IO.puts("JopLog now logging on memory joplog #{joplog.ets}.")
    log(joplog, @tag_start, "#{date_str()}")
  end

  @doc """
  returns a reference, in case the JopLog Struct
  returned by init/1 is used by different processes
  """
  @spec ref(joplog_name :: String.t()) :: JopLog.t()
  def ref(joplog_name) when is_binary(joplog_name) do
    tab = String.to_atom(joplog_name)

    IfValidEts.ets tab do
      %JopLog{ets: tab}
    else
      throw(:uninitialized)
    end
  end

  @doc """
  log in `%JopLog{}` key and value
  returns the updated `%JopLog{}`.
  """
  @spec log(JopLog.t(), any, any) :: JopLog.t()
  def log(%JopLog{ets: tab} = jop, key, value) do
    IfValidEts.ets(tab, do: ETS.insert(tab, {key, value, now_μs()}))
    jop
  end

  @doc """
  write a joplog on disk.
  2 logs are generated : dates.gz and keys.gz
  unless option :notstop is used, logging is stopped.
  """
  @spec flush(JopLog.t(), opt :: atom) :: JopLog.t()
  def flush(%JopLog{ets: tab} = joplog, opt \\ nil) do
    IfValidEts.ets tab do
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

      names = [fname(tab, "dates.gz"), fname(tab, "keys.gz")]

      [fa, fb] =
        for name <- names, do: File.open!(name, [:write, :compressed, encoding: :unicode])

      # factorize
      # flush log to the 'temporal' log file
      awaits = [
        {Task.async(fn ->
           for {k, op, t} <- List.keysort(logs, 2) do
             IO.puts(fa, "#{fmt_duration_us(t - t0)} #{inspect(k)}: #{inspect(op)}")
           end
         end), fa},
        # flush log to 'spatial' log file
        {Task.async(fn ->
           for {k, op, t} <- List.keysort(logs, 0) do
             IO.puts(fb, "#{inspect(k)}: #{fmt_duration_us(t - t0)} #{inspect(op)}")
           end
         end), fb}
      ]

      for {task, fd} <- awaits,
          do:
            (
              Task.await(task, :infinity)
              _ = File.close(fd)
            )

      IO.puts("log stored in :")
      for name <- names, do: IO.puts("- #{name}")
    end

    joplog
  end

  defp reset(%JopLog{ets: tab}) do
    IfValidEts.ets(tab,
      do: ETS.delete(tab)
    )
  end

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
    IfValidEts.ets tab do
      t0 = lookup_tag_start(tab)
      ETS.delete_all_objects(tab)

      if t0 do
        ETS.insert(tab, {@tag_start, t0, now_μs()})
      end
    end

    joplog
  end

  defp fname(tab, ext), do: ["jop_#{tab}", date_str(), "_", ext]

  defp now_μs(), do: System.monotonic_time(:microsecond)

  @date_format ".~p_~2.2.0w_~2.2.0w_~2.2.0w.~2.2.0w.~2.2.0w"
  @usecond_format "~2.2.0w:~2.2.0w:~2.2.0w_~3.3.0w.~3.3.0w"

  defp date_str() do
    hms =
      List.flatten(
        for e <- Tuple.to_list(:calendar.universal_time_to_local_time(:calendar.universal_time())) do
          Tuple.to_list(e)
        end
      )

    :io_lib.format(@date_format, hms)
  end

  defp fmt_duration_us(duration_us) do
    sec = div(duration_us, 1_000_000)
    rem_us = rem(duration_us, 1_000_000)
    ms = div(rem_us, 1000)
    us = rem(rem_us, 1000)
    {_, {h, m, s}} = :calendar.gregorian_seconds_to_datetime(sec)
    :io_lib.format(@usecond_format, [h, m, s, ms, us])
  end

  @doc """
  returns if the %JopLog{} is initialized with an ets table
  """
  def is_initialized(%JopLog{ets: ets}),
    do: IfValidEts.ets(ets, do: true, else: false)

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
      IfValidEts.ets tab do
        concat(["#JopLog<#{tab}:size(", to_doc(Enum.count(jop), opts), ")>"])
      else
        concat(["#JopLog<#{tab}:uninitialized>"])
      end
    end
  end
end
