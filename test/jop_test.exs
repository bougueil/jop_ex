defmodule JopTest do
  use ExUnit.Case
  doctest Jop

  def clean_jop_files(log) do
    for file <- Path.wildcard("jop_#{log}.*.gz"), do:  File.rm! file
  end

  test "log_and_dump" do
    log = :myjop
    JopTest.clean_jop_files(log)
    assert log == Jop.init(log)

    Jop.log(log, "mykey1", {:vv, 112})
    assert Jop.clear(log)

    assert log == Jop.log(log, "mykey2", {:vv, 113})
    assert log == Jop.log(log, "mykey1", {:vv, 112})
    assert log == Jop.log(log, "mykey2", {:vv, 113})
    assert 1 + 3 == Jop.size(log)  # +1 for start tag
    assert log == Jop.flush(log)
    assert :undefined == Jop.size(log)

    assert [] != Path.wildcard "jop_#{log}*.gz"
  end

  test "log_and_dump_continue" do
    log = :myjop
    JopTest.clean_jop_files(log)
    assert log == Jop.init(log)

    assert log == Jop.log(log, "mykey1", {:vv, 112})
    assert log == Jop.log(log, "mykey2", {:vv, 113})
    assert log == Jop.flush(log, :nostop)
    assert 1 + 2 == Jop.size(log)  # +1 for start tag
    assert [] != Path.wildcard "jop_#{log}*.gz"

    assert log == Jop.log(log, "mykey1", {:vv, 112})
    assert log == Jop.log(log, "mykey2", {:vv, 113})
    assert 1 + 2 + 2 == Jop.size(log)  # +1 for start tag
    assert log == Jop.flush(log)
    assert :undefined == Jop.size(log)
    assert [] != Path.wildcard "jop_#{log}*.gz"
  end

  test "uninitialized_log_and_dump" do
    log = :myjop
    JopTest.clean_jop_files(log)
    assert is_nil(Jop.log(log, "mykey1", {:vv, 112}))
    assert is_nil(Jop.log(log, "mykey2", {:vv, 113}))
    assert is_nil(Jop.flush(log))
    assert :undefined == Jop.size(log)
    assert [] == Path.wildcard "jop_#{log}*.gz"
  end

end
