defmodule Jop do
  alias :ets, as: ETS
  @tag_start "jop_start"

  @moduledoc """
  Documentation for Jop an in memory log

  ## Example

  iex> :mylog
  ...> |> Jop.init()
  ...> |> Jop.log("device_1", data: 112)
  ...> |> Jop.log("device_2", data: 113)
  ...> |> Jop.flush()
  ...> |> length() > 0
  true
  """

  @doc """
  Initialize the in memory log with the handle
  returns the handle
  """
  @spec init(atom) :: true
  def init(table) do
    clear(table)
  end

  @doc """
  Clear all entries in memory then
  reopens the ets table

  Returns the handle
  """
  @spec clear(atom) :: true
  def clear(table) do
    try do
      ETS.delete(table)
    rescue
      _ -> :ok
    end

    table = ETS.new(table, [:bag, :named_table, :public, :compressed])
    log(table, @tag_start, "")
  end

  @doc """
  log in `table` a key with its value
  returns the table handle
  """
  @spec log(atom, any, any) :: true
  def log(table, key, value) do
    try do
      true = ETS.insert(table, {key, value, now_us()})
    rescue
      _ -> :ok
    end

    table
  end

  @doc """
  flush the in memory log in 2 files : ordered timestamps & ordered keys files
  discards memory log data
  """
  @spec flush(atom) :: iolist
  def flush(table) do
    try do
     fname = fname(table, date_str())
      fd = File.open!([fname, "dates"], [:write])
      fb = File.open!([fname, "keys"], [:write])
      [{_, _, t0}] = ETS.lookup(table, @tag_start)

      ETS.delete(table, @tag_start)

      # flush log to the 'temporal' log file
      for {k, op, t} <- List.keysort(ETS.tab2list(table), 2) do
	IO.puts fd, "#{fmt_duration_us(t - t0)} #{inspect(k)}: #{inspect(op)}"
      end

      # flush log to 'spatial' log file
      for {k, op, t} <- List.keysort(ETS.tab2list(table), 0) do
	IO.puts fb, "#{inspect(k)}: #{inspect(op)} #{fmt_duration_us(t - t0)}"
      end

      for f <- [fd, fb], do: _ = File.close(f)
      ETS.delete(table)
      [dates_file: "#{[fname, "dates"]}", spatial_file: "#{[fname, "keys"]}"]
    rescue
      _ -> IO.puts "Error: no log in memory."
    end
  end

  defp fname(table, date), do: ["jop_", Atom.to_string(table), date, "_"]

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
