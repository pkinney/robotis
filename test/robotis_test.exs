defmodule RobotisTest do
  use ExUnit.Case
  doctest Robotis

  test "pings a device" do
    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert {:ok, ping_response} = Robotis.ping(pid, 0x01) |> IO.inspect()
  end
end
