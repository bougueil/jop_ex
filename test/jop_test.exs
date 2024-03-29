defmodule JopTest do
  use ExUnit.Case
  @jop_log "test_jop_log"

  #  doctest JopLog

  setup do
    on_exit(fn -> clean_jop_files(@jop_log) end)
  end

  test "ref from unitialized" do
    assert try do: JopLog.ref("bang"), catch: (any -> true), else: (_ -> false)
  end

  test "ref from initialized" do
    joplog = JopLog.init(@jop_log)
    assert try do: JopLog.ref(@jop_log), catch: (any -> false), else: (_ -> true)
    assert is_struct(joplog, JopLog)
  end

  test "double init" do
    joplog = JopLog.init(@jop_log)
    ^joplog = JopLog.init(@jop_log)
    assert is_struct(joplog, JopLog)
    assert Enum.empty?(joplog)
    assert joplog == JopLog.flush(joplog)
    assert all_logs_are_present?(@jop_log)
  end

  test "clear" do
    joplog = JopLog.init(@jop_log)
    JopLog.log(joplog, "key_1", :any_term_112)
    JopLog.clear(joplog)
    assert Enum.empty?(joplog)
    assert joplog == JopLog.flush(joplog)
    assert all_logs_are_present?(@jop_log)
  end

  test "flush" do
    joplog = JopLog.init(@jop_log)
    JopLog.log(joplog, "key_1", :any_term_112)
    JopLog.flush(joplog)
    refute JopLog.is_initialized(joplog)
    assert all_logs_are_present?(@jop_log)
  end

  test "flush nostop" do
    joplog = JopLog.init(@jop_log)
    JopLog.log(joplog, "key_1", :any_term_112)
    JopLog.flush(joplog, :nostop)
    assert joplog == JopLog.log(joplog, "mykey2", {:vv, 113})
    assert Enum.count(joplog) == 1
    assert joplog == JopLog.flush(joplog)
    assert all_logs_are_present?(@jop_log)
  end

  test "log_and_dump" do
    joplog = JopLog.init(@jop_log)
    assert is_struct(joplog, JopLog)

    assert joplog == JopLog.log(joplog, "mykey1", {:vv, 112})
    :timer.sleep(12)
    assert joplog == JopLog.init(@jop_log)

    assert joplog == JopLog.log(joplog, "mykey2", {:vv, 113})

    :timer.sleep(12)
    assert joplog = JopLog.log(joplog, "mykey1", {:vv, 112})

    :timer.sleep(12)
    assert joplog == JopLog.log(joplog, "mykey2", {:vv, 113})

    assert Enum.count(joplog) == 3
    assert joplog == JopLog.flush(joplog)
    assert all_logs_are_present?(@jop_log)
  end

  test "is_initialized" do
    job_ref = try do: JopLog.ref(@jop_log), catch: (any -> any)
    assert job_ref == :uninitialized
    joplog = JopLog.init(@jop_log)
    assert JopLog.is_initialized(joplog)

    assert joplog == JopLog.flush(joplog)
    assert all_logs_are_present?(@jop_log)
  end

  test "enumerable" do
    joplog = JopLog.init(@jop_log)
    assert is_struct(joplog, JopLog)
    assert joplog == JopLog.log(joplog, "mykey", "myvalue")
    assert joplog == JopLog.log(joplog, "mykey", "myvalue777")
    assert Enum.count(joplog) == 2
    assert Enum.member?(joplog, "mykey")
    assert 10 == Enum.reduce(joplog, 0, fn {_k, val}, acc -> max(byte_size(val), acc) end)
  end

  defp all_logs_are_present?(id),
    do: 2 == length(Path.wildcard("jop_#{id}*.gz"))

  def clean_jop_files(id) do
    for file <- Path.wildcard("jop_#{id}*.gz"),
        do: File.rm!(file)
  end
end
