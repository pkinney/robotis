defmodule Robotis.ControlTable do
  @moduledoc false
  alias Robotis.Utils

  import Bitwise

  @type param() :: atom()

  @type address() :: byte()
  @type length() :: non_neg_integer()
  @type conversion() ::
          :bool | number() | {module(), atom(), atom() | nil} | list({any(), binary()}) | nil
  @type param_info() :: {address(), length(), conversion()} | {address(), length()}

  @callback table() :: %{param() => param_info()}

  @spec info_for_param(module(), param()) :: param_info() | nil
  def info_for_param(control_table, param), do: control_table.table() |> Map.get(param)

  @spec address_and_length_for_param(module(), param()) :: {address(), length()}
  def address_and_length_for_param(control_table, param) do
    {address, len, _} = info_for_param(control_table, param)
    {address, len}
  end

  @spec decode_param(module(), param(), binary()) :: {:ok, any()} | {:error, any()}
  def decode_param(control_table, param, value) do
    case info_for_param(control_table, param) do
      {_, _, scale} when is_number(scale) -> {:ok, Utils.decode_int(value) * scale}
      {_, _, mapping} when is_list(mapping) -> decode_map(value, mapping)
      {_, _, :bool} -> {:ok, Utils.decode_boolean(value)}
      {_, _, {mod, fun, _}} -> {:ok, apply(mod, fun, [value])}
      nil -> {:error, {:unknown_param, param}}
    end
  end

  @spec encode_param(module(), param(), any()) :: {:ok, address(), binary()} | {:error, any()}
  def encode_param(control_table, param, value) do
    case info_for_param(control_table, param) do
      nil ->
        {:error, {:unknown_param, param}}

      {address, length, conversion} ->
        case conversion do
          scale when is_number(scale) -> (value / scale) |> trunc() |> Utils.encode_int(length)
          mapping when is_list(mapping) -> encode_map(value, mapping)
          :bool -> Utils.encode_boolean(value)
          {mod, _, fun} -> apply(mod, fun, [value])
        end
        |> case do
          nil -> {:error, :unconvertible_value}
          bytes -> {:ok, address, bytes}
        end
    end
  end

  defp decode_map(value, map) do
    Enum.find(map, &(elem(&1, 1) == value))
    |> case do
      {a, _} -> {:ok, a}
      _ -> {:error, :bad_decode}
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

  @spec xl330_decode_shutdown(<<_::8>>) ::
          list(
            :overload_error
            | :electrical_shock_error
            | :motor_encoder_error
            | :overheating_error
            | :overload_error
            | :input_voltage_error
          )
  def xl330_decode_shutdown(
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

  @spec xl330_encode_shutdown(
          list(
            :overload_error
            | :electrical_shock_error
            | :motor_encoder_error
            | :overheating_error
            | :overload_error
            | :input_voltage_error
          )
        ) :: <<_::8>>
  def xl330_encode_shutdown(flags) do
    <<Enum.reduce(flags, 0, fn
        :overload_error, acc -> acc ||| 1 <<< 5
        :electrical_shock_error, acc -> acc ||| 1 <<< 4
        :motor_encoder_error, acc -> acc ||| 1 <<< 3
        :overheating_error, acc -> acc ||| 1 <<< 2
        :input_voltage_error, acc -> acc ||| 1
      end)>>
  end

  @spec xm430_decode_shutdown(<<_::8>>) ::
          list(
            :overload_error
            | :electrical_shock_error
            | :motor_encoder_error
            | :overheating_error
            | :input_voltage_error
          )
  def xm430_decode_shutdown(
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

  @spec xm430_encode_shutdown(
          list(
            :overload_error
            | :electrical_shock_error
            | :motor_encoder_error
            | :overheating_error
            | :input_voltage_error
          )
        ) :: <<_::8>>
  def xm430_encode_shutdown(flags) do
    <<Enum.reduce(flags, 0, fn
        :overload_error, acc -> acc ||| 1 <<< 5
        :electrical_shock_error, acc -> acc ||| 1 <<< 4
        :motor_encoder_error, acc -> acc ||| 1 <<< 3
        :overheating_error, acc -> acc ||| 1 <<< 2
        :input_voltage_error, acc -> acc ||| 1
      end)>>
  end
end
