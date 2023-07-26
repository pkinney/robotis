defmodule RobotisTest do
  use ExUnit.Case

  doctest Robotis

  test "pings a device" do
    replay =
      Replay.replay_uart([
        {:write, <<255, 255, 253, 0, 1, 3, 0, 1, 25, 78>>},
        {:read,
         <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x07, 0x00, 0x55, 0x00, 0xB0, 0x04, 0x31, 0xAC, 0xD4>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert {:ok, ping_response} = Robotis.ping(pid, 0x01)
    assert ping_response.firmware == 49
    assert ping_response.id == 1
    assert ping_response.model_number == 1200
    assert ping_response.model == :xl330_m288
    Replay.assert_complete(replay)
  end

  test "should return :no_response for a ping that is not replied to" do
    replay =
      Replay.replay_uart([{:write, <<255, 255, 253, 0, 1, 3, 0, 1, 25, 78>>}, {:read, <<>>}])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert {:error, :no_response} = Robotis.ping(pid, 0x01)
    Replay.assert_complete(replay)
  end

  test "should return multiple ping responses for a broadcast ping" do
    replay =
      Replay.replay_uart([
        {:write, <<255, 255, 253, 0, 0xFE, 3, 0, 1, 0x31, 0x42>>},
        {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x07, 0x00, 0x55, 0x00, 0xB0>>},
        {:read,
         <<0x04, 0x31, 0xAC, 0xD4, 0xFF, 0xFF, 0xFD, 0x00, 0x02, 0x07, 0x00, 0x55, 0x00, 0xB0,
           0x04, 0x31>>},
        {:read, <<0xA6, 0xE4>>},
        {:read, <<>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    responses = Robotis.ping(pid)

    assert Enum.member?(
             responses,
             {:ok, %{id: 1, firmware: 49, model_number: 1200, model: :xl330_m288}}
           )

    assert Enum.member?(
             responses,
             {:ok, %{id: 2, firmware: 49, model_number: 1200, model: :xl330_m288}}
           )

    Replay.assert_complete(replay)
  end

  test "should return a response from a read command" do
    Replay.replay_uart([
      {:write,
       <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x07, 0x00, 0x02, 0x84, 0x00, 0x04, 0x00, 0x1D, 0x15>>},
      {:read,
       <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x08, 0x00, 0x55, 0x00, 0xA6, 0x00, 0x00, 0x00, 0x8C,
         0xC0>>}
    ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert {:ok, 14.58984375} = Robotis.read(pid, 1, :present_position)
  end

  test "should write a value without expecting a response" do
    Replay.replay_uart([
      {:write,
       <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x09, 0x00, 0x03, 0x74, 0x00, 0x00, 0x02, 0x00, 0x00, 0xCA,
         0x89>>}
    ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    value = Robotis.ControlTable.decode_param(:goal_position, <<0x00, 0x02, 0x00, 0x00>>)
    assert :ok = Robotis.write(pid, 1, :goal_position, value)
  end

  test "should write a value and expect a response" do
    replay =
      Replay.replay_uart([
        {:write,
         <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x09, 0x00, 0x03, 0x74, 0x00, 0x00, 0x02, 0x00, 0x00,
           0xCA, 0x89>>},
        {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x04, 0x00, 0x55, 0x00, 0xA1, 0x0C>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert :ok = Robotis.write(pid, 1, :goal_position, 45.0, true)
    Replay.assert_complete(replay)
  end

  test "should write a value and handle an bad CRC on response" do
    replay =
      Replay.replay_uart([
        {:write,
         <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x09, 0x00, 0x03, 0x74, 0x00, 0x00, 0x02, 0x00, 0x00,
           0xCA, 0x89>>},
        {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x04, 0x00, 0x55, 0x06, 0xA1, 0x0C>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert {:error, :invalid_crc} = Robotis.write(pid, 1, :goal_position, 45.0, true)
    Replay.assert_complete(replay)
  end

  test "should write a value and handle an error response" do
    replay =
      Replay.replay_uart([
        {:write, <<255, 255, 253, 0, 1, 9, 0, 3, 116, 0, 86, 249, 255, 255, 131, 61>>},
        {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x04, 0x00, 0x55, 0x06, 181, 12>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert {:error, :data_limit_error} = Robotis.write(pid, 1, :goal_position, -150.0, true)
    Replay.assert_complete(replay)
  end

  test "should write a mapping value" do
    Replay.replay_uart([
      {:write, <<255, 255, 253, 0, 1, 6, 0, 3, 10, 0, 4, 78, 227>>},
      {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x04, 0x00, 0x55, 0x00, 0xA1, 0x0C>>}
    ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert :ok = Robotis.write(pid, 1, :drive_mode, {:time_based, false}, true)
  end

  test "should return an error for an invalid mapping value" do
    Replay.replay_uart([])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert {:error, :unconvertible_value} =
             Robotis.write(pid, 1, :operating_mode, {:time_based, false}, true)
  end

  test "should write a boolean value" do
    replay =
      Replay.replay_uart([
        {:write, <<255, 255, 253, 0, 1, 6, 0, 3, 64, 0, 1, 0xDB, 0x66>>},
        {:write, <<255, 255, 253, 0, 1, 6, 0, 3, 64, 0, 0, 0xDE, 0xE6>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert :ok = Robotis.write(pid, 1, :torque_enable, true)
    assert :ok = Robotis.write(pid, 1, :torque_enable, false)
    Replay.await_complete(replay)
  end

  test "should write a function-encoded value" do
    replay =
      Replay.replay_uart([
        {:write, <<255, 255, 253, 0, 1, 6, 0, 3, 63, 0, 0x24, 0x09, 0x60>>},
        {:write, <<255, 255, 253, 0, 1, 6, 0, 3, 63, 0, 0x20, 0x12, 0xE0>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert :ok = Robotis.write(pid, 1, :shutdown, [:overload_error, :overheating_error])
    assert :ok = Robotis.write(pid, 1, :shutdown, [:overload_error])
    Replay.await_complete(replay)
  end

  test "should read a mapping value" do
    Replay.replay_uart([
      {:write, <<255, 255, 253, 0, 1, 7, 0, 2, 10, 0, 1, 0, 33, 211>>},
      {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x05, 0x00, 0x55, 0x00, 0x05, 0x4D, 0x21>>}
    ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert {:ok, {:time_based, true}} = Robotis.read(pid, 1, :drive_mode)
  end

  test "should read a function-encoded value" do
    Replay.replay_uart([
      {:write, <<255, 255, 253, 0, 1, 7, 0, 2, 63, 0, 1, 0, 43, 87>>},
      {:read, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x05, 0x00, 0x55, 0x00, 0x35, 0xED, 0x21>>}
    ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert {:ok, shutdown} = Robotis.read(pid, 1, :shutdown)

    assert shutdown == [
             :overload_error,
             :electrical_shock_error,
             :overheating_error,
             :input_voltage_error
           ]
  end

  test "should read a boolean value" do
    Replay.replay_uart([
      {:write, <<255, 255, 253, 0, 1, 7, 0, 2, 64, 0, 1, 0, 0x3C, 0xDB>>},
      {:read, <<255, 255, 253, 0, 1, 5, 0, 0x55, 0, 1, 0x56, 0xA1>>}
    ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert {:ok, true} = Robotis.read(pid, 1, :torque_enable)
  end

  test "should factory reset a device" do
    replay =
      Replay.replay_uart([
        {:write, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x04, 0x00, 0x06, 0x02, 0xAB, 0xE6>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert :ok = Robotis.factory_reset(pid, 1)
    Replay.await_complete(replay)
  end

  test "should reboot a device" do
    replay =
      Replay.replay_uart([
        {:write, <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x03, 0x00, 0x08, 0x2F, 0x4E>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert :ok = Robotis.reboot(pid, 1)
    Replay.await_complete(replay)
  end

  test "should clear the rotational position a device" do
    replay =
      Replay.replay_uart([
        {:write,
         <<0xFF, 0xFF, 0xFD, 0x00, 0x01, 0x08, 0x00, 0x10, 0x01, 0x44, 0x58, 0x4C, 0x22, 0xB1,
           0xDC>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert :ok = Robotis.clear(pid, 1)
    Replay.await_complete(replay)
  end

  test "should sync write to multiple devices" do
    replay =
      Replay.replay_uart([
        {:write,
         <<0xFF, 0xFF, 0xFD, 0x0, 0xFE, 0x11, 0x0, 0x83, 0x74, 0x0, 0x4, 0x0, 0x1, 0x0, 0x2, 0x0,
           0x0, 0x2, 0xC7, 0x5, 0x0, 0x0, 0x92, 0x80>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")
    assert :ok = Robotis.sync_write(pid, :goal_position, [{0x01, 45}, {0x02, 130}])
    Replay.await_complete(replay)
  end

  test "should fast sync read from multiple devices" do
    replay =
      Replay.replay_uart([
        {:write,
         <<0xFF, 0xFF, 0xFD, 0x00, 0xFE, 0x0A, 0x00, 0x8A, 0x84, 0x00, 0x04, 0x00, 0x03, 0x07,
           0x04, 0x20, 0xF2>>},
        {:read,
         <<0xFF, 0xFF, 0xFD, 0x00, 0xFE, 0x19, 0x00, 0x55, 0x00, 0x03, 0xA6, 0x00, 0x00, 0x00,
           0x84, 0x08>>},
        {:read, <<0x00, 0x07, 0x1F, 0x08, 0x00, 0x00, 0x16, 0xCA>>},
        {:read, <<0x00, 0x04, 0xFF, 0x03, 0x00, 0x00, 0xD1, 0x9E>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert [{3, {:ok, 14.58984375}}, {7, {:ok, 182.724609375}}, {4, {:ok, 89.912109375}}] ==
             Robotis.fast_sync_read(pid, [0x03, 0x07, 0x04], :present_position)

    Replay.await_complete(replay)
  end

  test "should fast sync read from multiple devices and handle an error from a device" do
    replay =
      Replay.replay_uart([
        {:write,
         <<0xFF, 0xFF, 0xFD, 0x00, 0xFE, 0x0A, 0x00, 0x8A, 0x84, 0x00, 0x04, 0x00, 0x03, 0x07,
           0x04, 0x20, 0xF2>>},
        {:read,
         <<0xFF, 0xFF, 0xFD, 0x00, 0xFE, 0x19, 0x00, 0x55, 0x00, 0x03, 0xA6, 0x00, 0x00, 0x00,
           0x84, 0x08>>},
        {:read, <<0x02, 0x07, 0x00, 0x00, 0x00, 0x00, 0x16, 0xCA>>},
        {:read, <<0x00, 0x04, 0xFF, 0x03, 0x00, 0x00, 0xA8, 0x73>>}
      ])

    {:ok, pid} = Robotis.start_link(uart_port: "mock")

    assert [{3, {:ok, 14.58984375}}, {7, {:error, :instruction_error}}, {4, {:ok, 89.912109375}}] ==
             Robotis.fast_sync_read(pid, [0x03, 0x07, 0x04], :present_position)

    Replay.await_complete(replay)
  end
end
