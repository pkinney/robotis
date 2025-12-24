defmodule Robotis.ControlTable.XM430 do
  @moduledoc """
  Control table for XM430 series servos (W210, W350).

  Protocol 2.0. Control table is similar to XL330 with same addresses and scaling.
  Main differences: model number, current limit unit (2.69mA vs 1mA).
  """
  @behaviour Robotis.ControlTable

  @velocity_factor 0.229
  @position_factor 0.087890625

  @impl true
  def table do
    %{
      model_number: {0, 2, 1},
      model_information: {2, 4, 1},
      firmware_version: {6, 1, 1},
      id: {7, 1, 1},
      baud_rate:
        {8, 1,
         [
           {9_600, <<0>>},
           {57_600, <<1>>},
           {115_200, <<2>>},
           {1_000_000, <<3>>},
           {2_000_000, <<4>>},
           {3_000_000, <<5>>},
           {4_000_000, <<6>>},
           {4_500_000, <<7>>}
         ]},
      return_delay_time: {9, 1, 2},
      drive_mode:
        {10, 1,
         [
           {{:velocity_based, false}, <<0>>},
           {{:velocity_based, true}, <<1>>},
           {{:time_based, false}, <<4>>},
           {{:time_based, true}, <<5>>}
         ]},
      operating_mode:
        {11, 1,
         [
           current_control: <<0>>,
           velocity_control: <<1>>,
           position_control: <<3>>,
           extended_position_control: <<4>>,
           current_based_position_control: <<5>>,
           pwm_control_mode: <<16>>
         ]},
      secondary_id: {12, 1, 1},
      protocol_type:
        {13, 1,
         [
           {:dynamixel_protocol_1, <<1>>},
           {:dynamixel_protocol_2, <<2>>}
         ]},
      homing_offset: {20, 4, @position_factor},
      moving_threshold: {24, 4, @velocity_factor},
      temperature_limit: {31, 1, 1},
      max_voltage_limit: {32, 2, 0.1},
      min_voltage_limit: {34, 2, 0.1},
      pwm_limit: {36, 2, 0.113},
      current_limit: {38, 2, 0.00269},
      velocity_limit: {44, 4, @velocity_factor},
      max_angle_limit: {48, 4, @position_factor},
      max_position_limit: {48, 4, @position_factor},
      min_position_limit: {52, 4, @position_factor},
      min_angle_limit: {52, 4, @position_factor},
      startup_configuration: {60, 1, 1},
      shutdown: {63, 1, {Robotis.ControlTable, :xm430_decode_shutdown, :xm430_encode_shutdown}},
      torque_enable: {64, 1, :bool},
      led: {65, 1, :bool},
      status_return_level: {68, 1, [{:ping, <<0>>}, {:ping_read, <<1>>}, {:all, <<2>>}]},
      registered_instruction: {69, 1, :bool},
      hardware_error_status: {70, 1, 1},
      velocity_i_gain: {76, 2, 1},
      velocity_p_gain: {78, 2, 1},
      position_d_gain: {80, 2, 1},
      position_i_gain: {82, 2, 1},
      position_p_gain: {84, 2, 1},
      feedforward_2nd_gain: {88, 2, 1},
      feedforward_1st_gain: {90, 2, 1},
      bus_watchdog: {98, 1, 1},
      goal_pwm: {100, 2, 0.113},
      goal_current: {102, 2, 0.00269},
      goal_velocity: {104, 4, @velocity_factor},
      profile_acceleration: {108, 4, 1},
      profile_velocity: {112, 4, @velocity_factor},
      goal_position: {116, 4, @position_factor},
      realtime_tick: {120, 2, 1},
      moving: {122, 1, :bool},
      moving_status: {123, 1, {Robotis.ControlTable, :decode_moving_status, nil}},
      present_pwm: {124, 2, 0.113},
      present_current: {126, 2, 0.00269},
      present_velocity: {128, 4, @velocity_factor},
      present_position: {132, 4, @position_factor},
      velocity_trajectory: {136, 4, @velocity_factor},
      position_trajectory: {140, 4, @position_factor},
      present_input_voltage: {144, 2, 0.1},
      present_temperature: {146, 1, 1},
      backup_ready: {147, 1, :bool},
      indirect_address_1: {168, 2, 1},
      indirect_address_2: {170, 2, 1},
      indirect_address_3: {172, 2, 1},
      indirect_address_4: {174, 2, 1},
      indirect_address_5: {176, 2, 1},
      indirect_address_6: {178, 2, 1},
      indirect_address_7: {180, 2, 1},
      indirect_address_8: {182, 2, 1},
      indirect_address_9: {184, 2, 1},
      indirect_address_10: {186, 2, 1},
      indirect_address_11: {188, 2, 1},
      indirect_address_12: {190, 2, 1},
      indirect_address_13: {192, 2, 1},
      indirect_address_14: {194, 2, 1},
      indirect_address_15: {196, 2, 1},
      indirect_address_16: {198, 2, 1},
      indirect_address_17: {200, 2, 1},
      indirect_address_18: {202, 2, 1},
      indirect_address_19: {204, 2, 1},
      indirect_address_20: {206, 2, 1},
      indirect_data_1: {208, 1, 1},
      indirect_data_2: {209, 1, 1},
      indirect_data_3: {210, 1, 1},
      indirect_data_4: {211, 1, 1},
      indirect_data_5: {212, 1, 1},
      indirect_data_6: {213, 1, 1},
      indirect_data_7: {214, 1, 1},
      indirect_data_8: {215, 1, 1},
      indirect_data_9: {216, 1, 1},
      indirect_data_10: {217, 1, 1},
      indirect_data_11: {218, 1, 1},
      indirect_data_12: {219, 1, 1},
      indirect_data_13: {220, 1, 1},
      indirect_data_14: {221, 1, 1},
      indirect_data_15: {222, 1, 1},
      indirect_data_16: {223, 1, 1},
      indirect_data_17: {224, 1, 1},
      indirect_data_18: {225, 1, 1},
      indirect_data_19: {226, 1, 1},
      indirect_data_20: {227, 1, 1}
    }
  end
end
