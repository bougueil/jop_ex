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
  Initialize Jop to log on memory bank `bank`
  returns the bank name
  """
  @spec init(atom) :: true
  def init(bank) when is_atom(bank) do
    clear(bank)
    IO.puts "BEWARE There is NO WAY to stop logging and filling the memory except by calling Jop.flush #{inspect(bank)}"
    IO.puts "Jop now logging on memory bank #{bank}."
    bank
  end

  @doc """
  Returns the number of elements in the memory bank `bank` or :undefined
  """
  @spec size(atom) :: pos_integer() | :undefined
  def size(bank) when is_atom(bank),
    do: ETS.info(bank, :size)

  @doc """
  Clear all entries in the memory bank `bank`
  reopens the memory bank

  Returns the handle
  """
  @spec clear(atom) :: true
  def clear(bank) when is_atom(bank) do
    If_valid.ets bank, do: ETS.delete(bank)
    ETS.new(bank, [:bag, :named_table, :public])
    |> log(@tag_start, "#{date_str()}")
  end


  @doc """
  log in the memory bank `bank` the key with its value
  returns the bank name
  """
  @spec log(atom, any, any) :: true
  def log(bank, key, value) when is_atom(bank) do
    If_valid.ets bank, do: ETS.insert(bank, {key, value, now_us()})
  end

  @doc """
  write the memory bank `bank` in 2 files dates.gz and keys.gz

  stop logging after flushing the memory bank unless opt is `:nostop`,
  """
  @spec flush(bank :: atom, opt :: atom) :: iolist
  def flush(bank, opt \\ nil) when is_atom(bank) do
    try do
      [{_, _, t0}] = ETS.lookup(bank, @tag_start)
      logs = ETS.tab2list(bank)

      if opt == :nostop do
	IO.puts "Jop continue logging.\nflushing memory bank #{bank} (#{Jop.size(bank)} records) on files ..."
      else
	IO.puts "Jop logging stopped.\nflushing memory bank #{bank} (#{Jop.size(bank)} records) on files ..."
	ETS.delete(bank)
     end

      names = [fname(bank, "dates.gz"), fname(bank, "keys.gz")]
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
    bank
  end

  defp fname(bank, ext), do: ["jop_", Atom.to_string(bank), date_str(), "_", ext]

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
