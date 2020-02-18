defmodule ZiglerTest.Integration.LongNifTest do

  use ExUnit.Case, async: true
  use Zigler

  ~Z"""
  /// nif: long_forty_seven/0 long
  fn long_forty_seven() i32 {
    // sleep for 2 seconds
    std.time.sleep(2000000000);
    return 47;
  }
  """

  test "long nifs can sleep for a while" do
    start = DateTime.utc_now
    assert 47 == long_forty_seven()
    elapsed = DateTime.utc_now |> DateTime.diff(start)
    assert elapsed >= 2 and elapsed < 4
  end

#  ~Z"""
#  /// nif: long_void/1 long
#  fn long_void(pid: beam.pid) void {
#    // sleep for 50 ms
#    std.time.sleep(50000000);
#  }
#  """
#
#  test "long nifs can have a void return" do
#    test_pid = self()
#    spawn(fn ->
#      long_void()
#      send(test_pid, :done)
#    end)
#    refute_receive :done, 25
#    assert_receive :done
#  end

end

