defmodule PerfTest do
  use ExUnit.Case
  @jop_log "test_jop_log"

  test "measure logging" do
    joplog = JopLog.init(@jop_log)

    n = 1000_000
    bench_fn = fn -> for i <- 1..n, do: JopLog.log(joplog, <<i::size(40)>>, {<<"data.", <<i:: size(40)>>::binary>>}) end
    {tlog, _} = :timer.tc(bench_fn)
    througput = div(n * 1_000_000, tlog)
    IO.puts("througput #{througput} logs/s.")
    assert Enum.count(joplog) == n
  end
end