defmodule Robotis.ControlTable.XL320 do
  @moduledoc """
  Control table for XL320 series servos.
  """
  @behaviour Robotis.ControlTable

  @impl true
  def table do
    %{
      model_number: {0, 2, 1},
      firmware_version: {2, 1, 1},
      id: {3, 1, 1},
      baud_rate:
        {4, 1,
         [
           {9_600, <<0>>},
           {57_000, <<1>>},
           {115_200, <<2>>},
           {1_000_000, <<3>>},
           {2_000_000, <<4>>},
           {3_000_000, <<5>>},
           {4_000_000, <<6>>}
         ]},
      return_delay_time: {5, 1, 2},
      cw_angle_limit: {6, 2, 0.29},
      ccw_angle_limit: {8, 2, 0.29},
      control_mode: {11, 1, [{:wheel_mode, <<1>>}, {:joint_mode, <<2>>}]},
      temperature_limit: {12, 1, 1},
      min_voltage_limit: {13, 1, 0.1},
      max_voltage_limit: {14, 1, 0.1},
      max_torque: {15, 2, 0.001},
      status_return_level: {17, 1, [{:ping, <<0>>}, {:ping_read, <<1>>}, {:all, <<2>>}]},
      shutdown: {18, 1, {Robotis.ControlTable, :xl320_decode_shutdown, :xl320_encode_shutdown}},
      torque_enable: {24, 1, :bool},
      led: {25, 1, 1},
      d_gain: {27, 1, 1 / 8},
      i_gain: {28, 1, 1000 / 2048},
      p_gain: {29, 1, 4 / 1000},
      goal_position: {30, 2, 0.29},
      moving_speed: {32, 2, 0.111},
      torque_limit: {35, 2, 0.001},
      present_position: {37, 2, 0.29},
      present_speed: {39, 2, 0.111},
      present_load: {41, 2, 0.001},
      present_voltage: {45, 1, 0.1},
      present_temperature: {46, 1, 1},
      registered_instruction: {47, 1, :bool},
      moving: {49, 1, :bool},
      hardware_error_status: {50, 1, 1},
      punch: {51, 2, 0.001}
    }
  end
end
