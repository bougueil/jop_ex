defmodule JopTest do
  use ExUnit.Case
  doctest Jop

  test "log_and_dump" do
    log = :myjop
    assert Jop.init(log)

    Jop.log(log, "mykey1", {:vv, 112})
    :timer.sleep(12)
    assert log == Jop.clear(log)

    assert log == Jop.log(log, "mykey2", {:vv, 113})

    :timer.sleep(12)
    assert log == Jop.log(log, "mykey1", {:vv, 112})

    :timer.sleep(12)
    assert log == Jop.log(log, "mykey2", {:vv, 113})

    prefix = Jop.flush(log)

    for fname <- [[prefix, "dates"], [prefix, "keys"]] do
      IO.puts("\n#{List.to_string(fname)} :\n#{File.read!(fname)}")
    end
  end
end
