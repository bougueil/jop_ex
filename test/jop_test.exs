defmodule JopTest do
  use ExUnit.Case
  doctest Jop

  test "log_and_dump" do
    log = :myjop
    assert log == Jop.init(log)

    Jop.log(log, "mykey1", {:vv, 112})
    :timer.sleep(12)
    assert Jop.clear(log)

    assert Jop.log(log, "mykey2", {:vv, 113})

    :timer.sleep(12)
    assert Jop.log(log, "mykey1", {:vv, 112})

    :timer.sleep(12)
    assert Jop.log(log, "mykey2", {:vv, 113})

    prefix = Jop.flush(log)
    assert [] != Path.wildcard "jop_#{prefix}*.gz"

  end
end
