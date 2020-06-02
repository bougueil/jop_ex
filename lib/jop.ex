defmodule If_valid do
  defmacro ets(tab, do: expression)  do
    quote do
      :undefined != :ets.info(unquote(tab), :size) && unquote(expression)
    end
  end
end

defmodule Jop do
  alias :ets, as: ETS
  require If_valid
  @tag_start "jop_start"

  @moduledoc """
  Documentation for Jop an in memory log

  ## Example

  iex> :mylog
  ...> |> Jop.init()
  ...> |> Jop.log("device_1", data: 112)
  ...> |> Jop.log("device_2", data: 113)
  ...> |> Jop.flush()
  ...> |> Jop.size() > 0
  true
  """

  @doc """
  Initialize the in memory log with the handle
  returns the handle
  """
  @spec init(atom) :: true
  def init(table),
    do: clear(table)

  @doc """
  Returns the number of elements in log or :undefined
  """
  @spec size(atom) :: pos_integer() | :undefined
  def size(table),
    do: ETS.info(table, :size)

  @doc """
  Clear all entries in log then
  reopens the ets table

  Returns the handle
  """
  @spec clear(atom) :: true
  def clear(table) do
    If_valid.ets table, do: ETS.delete(table)
    ETS.new(table, [:bag, :named_table, :public])
    |> log(@tag_start, "#{date_str()}")
  end


  @doc """
  log in `table` a key with its value
  returns the table handle
  """
  @spec log(atom, any, any) :: true
  def log(table, key, value) do
    If_valid.ets table, do: ETS.insert(table, {key, value, now_us()})
  end

  @doc """
  write the log `table` in 2 files dates.gz and keys.gz

  stop logging after flush unless opt is `:nostop`,
  """
  @spec flush(table :: atom, opt :: atom) :: iolist
  def flush(table, opt \\ nil) do
    try do
      [{_, _, t0}] = ETS.lookup(table, @tag_start)
      logs = ETS.tab2list(table)

      if opt == :nostop do
	IO.puts "Jop continue logging.\nflushing #{Jop.size(table)} records on files ..."
      else
	IO.puts "Jop logging stopped.\nflushing #{Jop.size(table)} records on files ..."
	ETS.delete(table)
     end

      names = [fname(table, "dates.gz"), fname(table, "keys.gz")]
      [fa, fb] = for name <- names, do: File.open!(name, [:write, :compressed, encoding: :unicode])

      # TODO factorize
      awaits =
	[{Task.async(fn -> # flush log to the 'temporal' log file
	     for {k, op, t} <- List.keysort(logs, 2) do
	       IO.puts fa, "#{fmt_duration_us(t - t0)} #{inspect(k)}: #{inspect(op)}"
	     end
	   end), fa},

	 {Task.async(fn -> # flush log to 'spatial' log file
	     for {k, op, t} <- List.keysort(logs, 0) do
	       IO.puts fb, "#{inspect(k)}: #{fmt_duration_us(t - t0)} #{inspect(op)}"
	     end
	   end), fb}]

      for {task, fd} <- awaits, do: (Task.await(task, :infinity); _ = File.close(fd))
      IO.puts "log stored in :"
      for name <- names, do: IO.puts "- #{name}"
    rescue
      _ -> IO.puts "Error: no log available."
    end
    table
  end

  defp fname(table, ext), do: ["jop_", Atom.to_string(table), date_str(), "_", ext]

  defp now_us(), do: System.monotonic_time(:microsecond)

  defp date_str() do
    hms =
      List.flatten(
        for e <- Tuple.to_list(:calendar.universal_time_to_local_time(:calendar.universal_time())) do
          Tuple.to_list(e)
        end
      )

    :io_lib.format(".~p_~2.2.0w_~2.2.0w_~2.2.0w.~2.2.0w.~2.2.0w", hms)
  end

  defp fmt_duration_us(duration_us) do
    sec = div(duration_us, 1_000_000)
    rem_us = rem(duration_us, 1_000_000)
    ms = div(rem_us, 1000)
    us = rem(rem_us, 1000)
    {_, {h, m, s}} = :calendar.gregorian_seconds_to_datetime(sec)
    :io_lib.format("~2.2.0w:~2.2.0w:~2.2.0w_~3.3.0w.~3.3.0w", [h, m, s, ms, us])
  end
end
