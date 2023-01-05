defmodule Robotis.ControlTable do
  alias Robotis.Utils

  import Bitwise

  @type param() ::
          :drive_mode
          | :operating_mode
          | :status_return_level
          | :return_delay_time
          | :max_angle_limit
          | :min_angle_limit
          | :torque_enabled
          | :goal_position
          | :moving
          | :moving_status
          | :present_current
          | :present_velocity
          | :present_position

  @type address() :: byte()
  @type length() :: non_neg_integer()
  @type conversion() :: :bool | number() | {module(), atom(), atom()} | list({any(), binary()})
  @type param_info() :: {address(), length(), conversion()}

  @spec info_for_param(param()) :: param_info()
  def info_for_param(param),
    do:
      %{
        drive_mode:
          {10, 1,
           [
             {{:velocity_based, false}, <<0x00>>},
             {{:velocity_based, true}, <<0x01>>},
             {{:time_based, false}, <<0x04>>},
             {{:time_based, true}, <<0x05>>}
           ]},
        operating_mode:
          {11, 1,
           [
             {:current_control, <<0x00>>},
             {:velocity_control, <<0x01>>},
             {:position_control, <<0x03>>},
             {:extended_position_control, <<0x04>>},
             {:current_based_position_control, <<0x05>>},
             {:pwm_control_mode, <<0x10>>}
           ]},
        status_return_level: {68, 1, 1},
        return_delay_time: {9, 1, 1},
        max_angle_limit: {48, 4, 360 / 4096.0},
        min_angle_limit: {52, 4, 360 / 4096.0},
        shutdown: {63, 1, {__MODULE__, :decode_shutdown, :encode_shutdown}},
        torque_enabled: {64, 1, :bool},
        goal_position: {116, 4, 360 / 4096.0},
        moving: {122, 1, :bool},
        moving_status: {123, 1, {__MODULE__, :decode_moving_status, nil}},
        present_current: {126, 2, 1},
        present_velocity: {128, 4, 0.229 * 360 / 60},
        present_position: {132, 4, 360 / 4096.0}
      }
      |> Map.get(param)

  @spec address_and_length_for_param(param()) :: {address(), length()}
  def address_and_length_for_param(param) do
    {address, len, _} = info_for_param(param)
    {address, len}
  end

  @spec decode_param(param(), binary()) :: {:ok, any()} | {:error, any()}
  def decode_param(param, value) do
    case info_for_param(param) do
      {_, _, scale} when is_number(scale) -> {:ok, Utils.decode_int(value) * scale}
      {_, _, mapping} when is_list(mapping) -> decode_map(value, mapping)
      {_, _, :bool} -> {:ok, Utils.decode_boolean(value)}
      {_, _, {mod, fun, _}} -> {:ok, apply(mod, fun, [value])}
    end
  end

  @spec encode_param(param(), any()) :: {:ok, address(), binary()} | {:error, any()}
  def encode_param(param, value) do
    {address, length, conversion} = info_for_param(param)

    case conversion do
      scale when is_number(scale) -> (value / scale) |> trunc() |> Utils.encode_int(length)
      mapping when is_list(mapping) -> encode_map(value, mapping)
      :bool -> Utils.encode_boolean(value)
      {mod, _, fun} -> apply(mod, fun, [value])
    end
    |> case do
      nil -> {:error, :unconvertable_value}
      bytes -> {:ok, address, bytes}
    end
  end

  defp decode_map(value, map) do
    Enum.find(map, &(elem(&1, 1) == value))
    |> case do
      {a, _} -> {:ok, a}
      _ -> {:error, :no_decode, value}
    end
  end

  defp encode_map(value, map) do
    Enum.find(map, &(elem(&1, 0) == value))
    |> case do
      {_, a} -> a
      nil -> nil
    end
  end

  ################################################################
  ## Function-based decodes
  ################################################################

  @spec decode_moving_status(<<_::8>>) ::
          %{
            arrived: boolean,
            following_error: boolean,
            in_progress: boolean,
            profile: :not_used | :rectangular | :trapezoidal | :triangular
          }
  def decode_moving_status(
        <<_::2, profile::2, following_error::1, _::1, in_progress::1, arrived::1>>
      ) do
    %{
      profile:
        case profile do
          0 -> :not_used
          1 -> :rectangular
          2 -> :triangular
          3 -> :trapezoidal
        end,
      following_error: following_error == 1,
      in_progress: in_progress == 1,
      arrived: arrived == 1
    }
  end

  @spec decode_shutdown(<<_::8>>) ::
          list(
            :overload_error
            | :electrical_shock_error
            | :motor_encoder_error
            | :overheating_error
            | :overload_error
            | :input_voltage_error
          )
  def decode_shutdown(
        <<0::2, overload_error::1, electrical_shock_error::1, motor_encoder_error::1,
          overheating_error::1, _::1, input_voltage_error::1>>
      ) do
    [
      overload_error: overload_error,
      electrical_shock_error: electrical_shock_error,
      motor_encoder_error: motor_encoder_error,
      overheating_error: overheating_error,
      input_voltage_error: input_voltage_error
    ]
    |> Enum.filter(&(elem(&1, 1) == 1))
    |> Enum.map(&elem(&1, 0))
  end

  @spec encode_shutdown(
          list(
            :overload_error
            | :electrical_shock_error
            | :motor_encoder_error
            | :overheating_error
            | :overload_error
            | :input_voltage_error
          )
        ) :: <<_::8>>
  def encode_shutdown(flags) do
    <<Enum.reduce(flags, 0, fn
        :overload_error, acc -> acc ||| 1 <<< 5
        :electrical_shock_error, acc -> acc ||| 1 <<< 4
        :motor_encoder_error, acc -> acc ||| 1 <<< 3
        :overheating_error, acc -> acc ||| 1 <<< 2
        :input_voltage_error, acc -> acc ||| 1
      end)>>
  end

  @tables %{
    xl320: %{
      baud_rate: %{
        address: 4,
        description: "Communication Speed",
        initial: 3,
        max: 3,
        min: 0,
        size: 1,
        type: :read_write
      },
      ccw_angle_limit: %{
        address: 8,
        description: "Counter-Clockwise Angle Limit",
        initial: 1023,
        max: 1023,
        min: 0,
        size: 2,
        type: :read_write
      },
      control_mode: %{
        address: 11,
        description: "Control Mode",
        initial: 2,
        max: 2,
        min: 1,
        size: 1,
        type: :read_write
      },
      cw_angle_limit: %{
        address: 6,
        description: "Clockwise Angle Limit",
        initial: 0,
        max: 1023,
        min: 0,
        size: 2,
        type: :read_write
      },
      d_gain: %{
        address: 27,
        description: "Derivative Gain",
        initial: 0,
        max: 254,
        min: 0,
        size: 1,
        type: :read_write
      },
      firmware_version: %{
        address: 2,
        description: "Firmware Version",
        initial: nil,
        max: nil,
        min: nil,
        size: 1,
        type: :read
      },
      goal_position: %{
        address: 30,
        description: "Desired Position",
        initial: nil,
        max: 1023,
        min: 0,
        size: 2,
        type: :read_write
      },
      hardware_error_status: %{
        address: 50,
        description: "Hardware Error Status",
        initial: 0,
        max: nil,
        min: nil,
        size: 1,
        type: :read
      },
      i_gain: %{
        address: 28,
        description: "Integral Gain",
        initial: 0,
        max: 254,
        min: 0,
        size: 1,
        type: :read_write
      },
      id: %{
        address: 3,
        description: "DYNAMIXEL ID",
        initial: 1,
        max: 252,
        min: 0,
        size: 1,
        type: :read_write
      },
      led: %{
        address: 25,
        description: "Status LED On/Off",
        initial: 0,
        max: 7,
        min: 0,
        size: 1,
        type: :read_write
      },
      max_torque: %{
        address: 15,
        description: "Maximun Torque",
        initial: 1023,
        max: 1023,
        min: 0,
        size: 2,
        type: :read_write
      },
      max_voltage_limit: %{
        address: 14,
        description: "Maximum Input Voltage Limit",
        initial: 90,
        max: 250,
        min: 50,
        size: 1,
        type: :read_write
      },
      min_voltage_limit: %{
        address: 13,
        description: "Minimum Input Voltage Limit",
        initial: 60,
        max: 250,
        min: 50,
        size: 1,
        type: :read_write
      },
      model_number: %{
        address: 0,
        description: "Model Number",
        initial: 350,
        max: nil,
        min: nil,
        size: 2,
        type: :read
      },
      moving: %{
        address: 49,
        description: "Movement Status",
        initial: 0,
        max: nil,
        min: nil,
        size: 1,
        type: :read
      },
      moving_speed: %{
        address: 32,
        description: "Moving Speed(Moving Velocity)",
        initial: nil,
        max: 2047,
        min: 0,
        size: 2,
        type: :read_write
      },
      p_gain: %{
        address: 29,
        description: "Proportional Gain",
        initial: 32,
        max: 254,
        min: 0,
        size: 1,
        type: :read_write
      },
      present_load: %{
        address: 41,
        description: "Present Load",
        initial: nil,
        max: nil,
        min: nil,
        size: 2,
        type: :read
      },
      present_position: %{
        address: 37,
        description: "Present Position",
        initial: nil,
        max: nil,
        min: nil,
        size: 2,
        type: :read
      },
      present_speed: %{
        address: 39,
        description: "Present Speed",
        initial: nil,
        max: nil,
        min: nil,
        size: 2,
        type: :read
      },
      present_temperature: %{
        address: 46,
        description: "Present Temperature",
        initial: nil,
        max: nil,
        min: nil,
        size: 1,
        type: :read
      },
      present_voltage: %{
        address: 45,
        description: "Present Voltage",
        initial: nil,
        max: nil,
        min: nil,
        size: 1,
        type: :read
      },
      punch: %{
        address: 51,
        description: "Minimum Current Threshold",
        initial: 32,
        max: 1023,
        min: 0,
        size: 2,
        type: :read_write
      },
      registered_instruction: %{
        address: 47,
        description: "If Instruction is registered",
        initial: 0,
        max: nil,
        min: nil,
        size: 1,
        type: :read
      },
      return_delay_time: %{
        address: 5,
        description: "Response Delay Time",
        initial: 250,
        max: 254,
        min: 0,
        size: 1,
        type: :read_write
      },
      shutdown: %{
        address: 18,
        description: "Shutdown Error Information",
        initial: 3,
        max: 7,
        min: 0,
        size: 1,
        type: :read_write
      },
      status_return_level: %{
        address: 17,
        description: "Select Types of Status Return",
        initial: 2,
        max: 2,
        min: 0,
        size: 1,
        type: :read_write
      },
      temperature_limit: %{
        address: 12,
        description: "Maximum Internal Temperature Limit",
        initial: 65,
        max: 150,
        min: 0,
        size: 1,
        type: :read_write
      },
      torque_enable: %{
        address: 24,
        description: "Motor Torque On/Off",
        initial: 0,
        max: 1,
        min: 0,
        size: 1,
        type: :read_write
      },
      torque_limit: %{
        address: 35,
        description: "Torque Limit",
        initial: nil,
        max: 1023,
        min: 0,
        size: 2,
        type: :read_write
      }
    },
    xl330_m288: %{
      indirect_data_15: %{
        address: 222,
        description: "Indirect Data 15",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_data_4: %{
        address: 211,
        description: "Indirect Data 4",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_address_20: %{
        address: 206,
        description: "Indirect Address 20",
        initial: 227,
        size: 2,
        type: :read_write
      },
      indirect_address_7: %{
        address: 180,
        description: "Indirect Address 7",
        initial: 214,
        size: 2,
        type: :read_write
      },
      indirect_address_9: %{
        address: 184,
        description: "Indirect Address 9",
        initial: 216,
        size: 2,
        type: :read_write
      },
      indirect_data_17: %{
        address: 224,
        description: "Indirect Data 17",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_address_13: %{
        address: 192,
        description: "Indirect Address 13",
        initial: 220,
        size: 2,
        type: :read_write
      },
      shutdown: %{
        address: 63,
        description: "Shutdown",
        initial: 53,
        size: 1,
        type: :read_write
      },
      max_voltage_limit: %{
        address: 32,
        description: "Max Voltage Limit",
        initial: 70,
        size: 2,
        type: :read_write
      },
      min_voltage_limit: %{
        address: 34,
        description: "Min Voltage Limit",
        initial: 35,
        size: 2,
        type: :read_write
      },
      pwm_limit: %{
        address: 36,
        description: "PWM Limit",
        initial: 885,
        size: 2,
        type: :read_write
      },
      indirect_data_3: %{
        address: 210,
        description: "Indirect Data 3",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_data_8: %{
        address: 215,
        description: "Indirect Data 8",
        initial: 0,
        size: 1,
        type: :read_write
      },
      model_number: %{
        address: 0,
        description: "Model Number",
        initial: 1200,
        size: 2,
        type: :read
      },
      indirect_address_17: %{
        address: 200,
        description: "Indirect Address 17",
        initial: 224,
        size: 2,
        type: :read_write
      },
      indirect_address_5: %{
        address: 176,
        description: "Indirect Address 5",
        initial: 212,
        size: 2,
        type: :read_write
      },
      indirect_data_14: %{
        address: 221,
        description: "Indirect Data 14",
        initial: 0,
        size: 1,
        type: :read_write
      },
      id: %{address: 7, description: "ID", initial: 1, size: 1, type: :read_write},
      indirect_address_8: %{
        address: 182,
        description: "Indirect Address 8",
        initial: 215,
        size: 2,
        type: :read_write
      },
      indirect_address_19: %{
        address: 204,
        description: "Indirect Address 19",
        initial: 226,
        size: 2,
        type: :read_write
      },
      goal_position: %{
        address: 116,
        description: "Goal Position",
        initial: nil,
        size: 4,
        type: :read_write
      },
      pwm_slope: %{
        address: 62,
        description: "PWM Slope",
        initial: 140,
        size: 1,
        type: :read_write
      },
      homing_offset: %{
        address: 20,
        description: "Homing Offset",
        initial: 0,
        size: 4,
        type: :read_write
      },
      firmware_version: %{
        address: 6,
        description: "Firmware Version",
        initial: nil,
        size: 1,
        type: :read
      },
      indirect_data_2: %{
        address: 209,
        description: "Indirect Data 2",
        initial: 0,
        size: 1,
        type: :read_write
      },
      hardware_error_status: %{
        address: 70,
        description: "Hardware Error Status",
        initial: 0,
        size: 1,
        type: :read
      },
      indirect_data_10: %{
        address: 217,
        description: "Indirect Data 10",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_address_11: %{
        address: 188,
        description: "Indirect Address 11",
        initial: 218,
        size: 2,
        type: :read_write
      },
      indirect_address_3: %{
        address: 172,
        description: "Indirect Address 3",
        initial: 210,
        size: 2,
        type: :read_write
      },
      moving_status: %{
        address: 123,
        description: "Moving Status",
        initial: 0,
        size: 1,
        type: :read
      },
      present_input_voltage: %{
        address: 144,
        description: "Present Input Voltage",
        initial: nil,
        size: 2,
        type: :read
      },
      position_trajectory: %{
        address: 140,
        description: "Position Trajectory",
        initial: nil,
        size: 4,
        type: :read
      },
      present_position: %{
        address: 132,
        description: "Present Position",
        initial: nil,
        size: 4,
        type: :read
      },
      torque_enable: %{
        address: 64,
        description: "Torque Enable",
        initial: 0,
        size: 1,
        type: :read_write
      },
      led: %{
        address: 65,
        description: "LED",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_data_9: %{
        address: 216,
        description: "Indirect Data 9",
        initial: 0,
        size: 1,
        type: :read_write
      },
      bus_watchdog: %{
        address: 98,
        description: "Bus Watchdog",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_address_2: %{
        address: 170,
        description: "Indirect Address 2",
        initial: 209,
        size: 2,
        type: :read_write
      },
      protocol_type: %{
        address: 13,
        description: "Protocol Type",
        initial: 2,
        size: 1,
        type: :read_write
      },
      indirect_address_16: %{
        address: 198,
        description: "Indirect Address 16",
        initial: 223,
        size: 2,
        type: :read_write
      },
      velocity_limit: %{
        address: 44,
        description: "Velocity Limit",
        initial: 445,
        size: 4,
        type: :read_write
      },
      indirect_address_14: %{
        address: 194,
        description: "Indirect Address 14",
        initial: 221,
        size: 2,
        type: :read_write
      },
      goal_pwm: %{
        address: 100,
        description: "Goal PWM",
        initial: nil,
        size: 2,
        type: :read_write
      },
      position_d_gain: %{
        address: 80,
        description: "Position D Gain",
        initial: 0,
        size: 2,
        type: :read_write
      },
      realtime_tick: %{
        address: 120,
        description: "Realtime Tick",
        initial: nil,
        size: 2,
        type: :read
      },
      indirect_address_18: %{
        address: 202,
        description: "Indirect Address 18",
        initial: 225,
        size: 2,
        type: :read_write
      },
      indirect_data_19: %{
        address: 226,
        description: "Indirect Data 19",
        initial: 0,
        size: 1,
        type: :read_write
      },
      present_pwm: %{
        address: 124,
        description: "Present PWM",
        initial: nil,
        size: 2,
        type: :read
      },
      startup_configuration: %{
        address: 60,
        description: "Startup Configuration",
        initial: 0,
        size: 1,
        type: :read_write
      },
      present_temperature: %{
        address: 146,
        description: "Present Temperature",
        initial: nil,
        size: 1,
        type: :read
      },
      profile_velocity: %{
        address: 112,
        description: "Profile Velocity",
        initial: 0,
        size: 4,
        type: :read_write
      },
      profile_acceleration: %{
        address: 108,
        description: "Profile Acceleration",
        initial: 0,
        size: 4,
        type: :read_write
      },
      indirect_data_6: %{
        address: 213,
        description: "Indirect Data 6",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_data_20: %{
        address: 227,
        description: "Indirect Data 20",
        initial: 0,
        size: 1,
        type: :read_write
      },
      present_current: %{
        address: 126,
        description: "Present Current",
        initial: nil,
        size: 2,
        type: :read
      },
      indirect_data_7: %{
        address: 214,
        description: "Indirect Data 7",
        initial: 0,
        size: 1,
        type: :read_write
      },
      velocity_p_gain: %{
        address: 78,
        description: "Velocity P Gain",
        initial: 180,
        size: 2,
        type: :read_write
      },
      indirect_address_15: %{
        address: 196,
        description: "Indirect Address 15",
        initial: 222,
        size: 2,
        type: :read_write
      },
      indirect_data_5: %{
        address: 212,
        description: "Indirect Data 5",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_address_10: %{
        address: 186,
        description: "Indirect Address 10",
        initial: 217,
        size: 2,
        type: :read_write
      },
      position_i_gain: %{
        address: 82,
        description: "Position I Gain",
        initial: 0,
        size: 2,
        type: :read_write
      },
      indirect_address_4: %{
        address: 174,
        description: "Indirect Address 4",
        initial: 211,
        size: 2,
        type: :read_write
      },
      current_limit: %{
        address: 38,
        description: "Current Limit",
        initial: 1750,
        size: 2,
        type: :read_write
      },
      indirect_data_1: %{
        address: 208,
        description: "Indirect Data 1",
        initial: 0,
        size: 1,
        type: :read_write
      },
      operating_mode: %{
        address: 11,
        description: "Operating Mode",
        initial: 3,
        size: 1,
        type: :read_write
      },
      return_delay_time: %{
        address: 9,
        description: "Return Delay Time",
        initial: 250,
        size: 1,
        type: :read_write
      },
      indirect_data_13: %{
        address: 220,
        description: "Indirect Data 13",
        initial: 0,
        size: 1,
        type: :read_write
      },
      drive_mode: %{
        address: 10,
        description: "Drive Mode",
        initial: 0,
        size: 1,
        type: :read_write
      },
      feedforward_2nd_gain: %{
        address: 88,
        description: "Feedforward 2nd Gain",
        initial: 0,
        size: 2,
        type: :read_write
      },
      registered_instruction: %{
        address: 69,
        description: "Registered Instruction",
        initial: 0,
        size: 1,
        type: :read
      },
      min_position_limit: %{
        address: 52,
        description: "Min Position Limit",
        initial: 0,
        size: 4,
        type: :read_write
      },
      feedforward_1st_gain: %{
        address: 90,
        description: "Feedforward 1st Gain",
        initial: 0,
        size: 2,
        type: :read_write
      },
      indirect_address_6: %{
        address: 178,
        description: "Indirect Address 6",
        initial: 213,
        size: 2,
        type: :read_write
      },
      indirect_data_16: %{
        address: 223,
        description: "Indirect Data 16",
        initial: 0,
        size: 1,
        type: :read_write
      },
      goal_velocity: %{
        address: 104,
        description: "Goal Velocity",
        initial: nil,
        size: 4,
        type: :read_write
      },
      velocity_trajectory: %{
        address: 136,
        description: "Velocity Trajectory",
        initial: nil,
        size: 4,
        type: :read
      },
      max_position_limit: %{
        address: 48,
        description: "Max Position Limit",
        initial: 4095,
        size: 4,
        type: :read_write
      },
      moving_threshold: %{
        address: 24,
        description: "Moving Threshold",
        initial: 10,
        size: 4,
        type: :read_write
      },
      goal_current: %{
        address: 102,
        description: "Goal Current",
        initial: nil,
        size: 2,
        type: :read_write
      },
      model_information: %{
        address: 2,
        description: "Model Information",
        initial: nil,
        size: 4,
        type: :read
      },
      position_p_gain: %{
        address: 84,
        description: "Position P Gain",
        initial: 400,
        size: 2,
        type: :read_write
      },
      velocity_i_gain: %{
        address: 76,
        description: "Velocity I Gain",
        initial: 1600,
        size: 2,
        type: :read_write
      },
      present_velocity: %{
        address: 128,
        description: "Present Velocity",
        initial: nil,
        size: 4,
        type: :read
      },
      indirect_address_12: %{
        address: 190,
        description: "Indirect Address 12",
        initial: 219,
        size: 2,
        type: :read_write
      },
      indirect_data_18: %{
        address: 225,
        description: "Indirect Data 18",
        initial: 0,
        size: 1,
        type: :read_write
      },
      backup_ready: %{
        address: 147,
        description: "Backup Ready",
        initial: nil,
        size: 1,
        type: :read
      },
      indirect_data_12: %{
        address: 219,
        description: "Indirect Data 12",
        initial: 0,
        size: 1,
        type: :read_write
      },
      indirect_data_11: %{
        address: 218,
        description: "Indirect Data 11",
        initial: 0,
        size: 1,
        type: :read_write
      },
      baud_rate: %{
        address: 8,
        description: "Baud Rate",
        initial: 1,
        size: 1,
        type: :read_write
      },
      "secondary(shadow)_id": %{
        address: 12,
        description: "Secondary(Shadow) ID",
        initial: 255,
        size: 1,
        type: :read_write
      },
      temperature_limit: %{
        address: 31,
        description: "Temperature Limit",
        initial: 70,
        size: 1,
        type: :read_write
      },
      indirect_address_1: %{
        address: 168,
        description: "Indirect Address 1",
        initial: 208,
        size: 2,
        type: :read_write
      },
      moving: %{
        address: 122,
        description: "Moving",
        initial: 0,
        size: 1,
        type: :read
      },
      status_return_level: %{
        address: 68,
        description: "Status Return Level",
        initial: 2,
        size: 1,
        type: :read_write
      }
    }
  }
end
