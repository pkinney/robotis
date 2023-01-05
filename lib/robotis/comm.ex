defmodule Robotis.Comm do
  require Logger
  import Bitwise
  alias Robotis.Comm.CRC
  alias Robotis.{Ping, Utils}

  @type servo_error() ::
          :hardware_alert
          | :result_fail
          | :instruction_error
          | :data_range_error
          | :data_length_error
          | :data_limit_error
          | :access_error
          | :unknown_error
  @type servo_id() :: byte()
  @type instruction() :: byte()
  @type result() :: {:ok, binary(), servo_id()} | {:error, servo_error()}

  @header <<0xFF, 0xFF, 0xFD, 0x00>>

  defp uart_mod(), do: Resolve.resolve(Circuits.UART)

  @spec open(String.t(), non_neg_integer()) :: {:ok, Robotis.connect()} | {:error, any()}
  def open(uart_port, speed) do
    with {:ok, uart} <- uart_mod().start_link(),
         :ok <- uart_mod().open(uart, uart_port, speed: speed, active: false) do
      {:ok, %{uart: uart}}
    end
  end

  @spec ping(Robotis.connect()) :: list(result())
  def ping(connect) do
    :ok = build_message(0x01, 0xFE) |> send_uart(connect)
    receive_many(connect)
  end

  @spec ping(Robotis.connect(), servo_id()) :: result()
  def ping(connect, id) do
    :ok = build_message(0x01, id) |> send_uart(connect)
    receive_one(connect)
  end

  @spec write(Robotis.connect(), servo_id(), byte(), binary()) :: :ok | {:error, any()}
  def write(connect, id, address, params) do
    build_message(0x03, id, Utils.encode_int(address, 2) <> params) |> send_uart(connect)
  end

  @spec write_and_await_status(Robotis.connect(), servo_id(), byte(), binary()) ::
          result()
  def write_and_await_status(connect, id, address, params) do
    :ok = build_message(0x03, id, Utils.encode_int(address, 2) <> params) |> send_uart(connect)
    receive_one(connect)
  end

  @spec read(Robotis.connect(), servo_id(), byte(), non_neg_integer()) :: result()
  def read(connect, id, address, length) do
    :ok =
      build_message(0x02, id, Utils.encode_int(address, 2) <> Utils.encode_int(length, 2))
      |> send_uart(connect)

    receive_one(connect)
  end

  @spec fast_sync_read(Robotis.connect(), list(servo_id()), byte(), non_neg_integer) ::
          list(result())
  def fast_sync_read(connect, ids, address, length) do
    params =
      Utils.encode_int(address, 2) <> Utils.encode_int(length, 2) <> :binary.list_to_bin(ids)

    msg = build_message(0x8A, 0xFE, params)

    with :ok <- send_uart(msg, connect),
         {:ok, resp, _, _} <- receive_one(connect),
         responses <- decode_fast_sync_read_response(<<0>> <> resp, length) do
      responses
    else
      _ -> Enum.map(ids, &{:error, &1, nil})
    end
  end

  @spec factory_reset(Robotis.connect(), servo_id(), byte()) :: :ok | {:error, any()}
  def factory_reset(servo, id, param \\ 0x02) do
    build_message(0x06, id, <<param>>) |> send_uart(servo)
  end

  @spec reboot(Robotis.connect(), servo_id()) :: :ok | {:error, any()}
  def reboot(servo, id) do
    build_message(0x08, id) |> send_uart(servo)
  end

  @spec clear(Robotis.connect(), servo_id()) :: :ok | {:error, any()}
  def clear(servo, id) do
    build_message(0x10, id, <<0x01, 0x44, 0x58, 0x4C, 0x22>>) |> send_uart(servo)
  end

  defp build_message(instruction, id, params \\ "") do
    msg = @header <> <<id, byte_size(params) + 3, 0x00>> <> <<instruction>> <> params
    msg |> CRC.append_crc()
  end

  defp send_uart(msg, connect) do
    # Logger.info("[#{__MODULE__}] Sending #{inspect(msg, base: :hex)}")
    uart_mod().write(connect.uart, msg)
  end

  defp receive_one(connect) do
    res = do_receive_one(connect, "")
    res
  end

  defp do_receive_one(servo, buffer) do
    case finish_packet(buffer) do
      {:complete, packet, _leftover} ->
        decode_packet(packet)

      :incomplete ->
        uart_mod().read(servo.uart, 100)
        |> case do
          {:ok, ""} ->
            {:error, :no_response}

          {:ok, data} ->
            do_receive_one(servo, buffer <> data)
            # e -> e
        end

      :error ->
        {:error, :invalid_packet}
    end
  end

  def receive_many(servo) do
    res = do_receive_many(servo, "")
    # Logger.info("[#{__MODULE__}] Received many #{inspect(res, base: :hex)}")
    res
  end

  defp do_receive_many(servo, buffer) do
    case finish_packet(buffer) do
      {:complete, packet, leftover} ->
        [decode_packet(packet) | do_receive_many(servo, leftover)]

      :incomplete ->
        uart_mod().read(servo.uart, 100)
        |> case do
          {:ok, ""} -> []
          {:ok, data} -> do_receive_many(servo, buffer <> data)
          e -> e
        end
    end
  end

  defp finish_packet(msg) when byte_size(msg) < 7, do: :incomplete

  defp finish_packet(@header <> <<_id, l0, l1>> <> payload = data) do
    length = l0 + (l1 <<< 8)

    if byte_size(payload) >= length do
      <<packet::binary-size(7 + length)>> <> leftover = data
      {:complete, packet, leftover}
    else
      :incomplete
    end
  end

  defp finish_packet(_), do: :error

  defp decode_packet(packet) do
    # Logger.info("[#{__MODULE__}] Received packet: #{inspect(packet, base: :hex)}")

    with {:ok, body} <- CRC.validate_crc(packet),
         {:ok, id, _, error, params} <- split_body(body),
         :ok <- check_error(error) do
      {:ok, params, id}
    end
  end

  defp split_body(@header <> <<id, _, _, instruction, error, params::binary>>),
    do: {:ok, id, instruction, error, params}

  defp split_body(_), do: {:error, :invalid_message_format}

  def decode_fast_sync_read_response(data, length) do
    do_decode_fast_sync_read_response(data, length)
  end

  defp do_decode_fast_sync_read_response(data, length) do
    case data do
      <<error, id, value::binary-size(length), _crc::binary-size(2)>> <> rest ->
        [{decode_error(error), id, value} | do_decode_fast_sync_read_response(rest, length)]

      <<error, id, value::binary-size(length)>> ->
        [{decode_error(error), id, value}]

      _ ->
        []
    end
  end

  defp check_error(0x00), do: :ok
  defp check_error(err), do: {:error, decode_error(err)}

  defp decode_error(<<0>>), do: :ok
  defp decode_error(<<1::1, _::7>>), do: :hardware_alert
  defp decode_error(<<0::1, 1::7>>), do: :result_fail
  defp decode_error(<<0::1, 2::7>>), do: :instruction_error
  defp decode_error(<<0::1, 3::7>>), do: :crc_error
  defp decode_error(<<0::1, 4::7>>), do: :data_range_error
  defp decode_error(<<0::1, 5::7>>), do: :data_length_error
  defp decode_error(<<0::1, 6::7>>), do: :data_limit_error
  defp decode_error(<<0::1, 7::7>>), do: :access_error
  defp decode_error(0), do: :ok
  defp decode_error(1), do: :result_fail
  defp decode_error(2), do: :instruction_error
  defp decode_error(3), do: :crc_error
  defp decode_error(4), do: :data_range_error
  defp decode_error(5), do: :data_length_error
  defp decode_error(6), do: :data_limit_error
  defp decode_error(7), do: :access_error
  defp decode_error(n) when is_integer(n), do: decode_error(<<n>>)
  defp decode_error(_), do: :unknown_error
end
