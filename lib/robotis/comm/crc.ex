defmodule Robotis.Comm.CRC do
  @moduledoc false

  # The Dynamixel protocol2 uses a CRC16 with polynomial 0x8005 and initial value of 0.
  # This is the same as the CRC16-Buypass variant.
  @crc :cerlc.init(:crc16_buypass)

  @spec append_crc(binary()) :: binary()
  def append_crc(msg) do
    <<msg::binary, crc(msg)::little-16>>
  end

  @spec validate_crc(binary()) :: {:ok, binary()} | {:error, :invalid_crc}
  def validate_crc(packet) do
    body_size = byte_size(packet) - 2
    <<body::binary-size(body_size), crc::little-16>> = packet

    if crc == crc(body) do
      {:ok, body}
    else
      {:error, :invalid_crc}
    end
  end

  defp crc(msg) do
    :cerlc.calc_crc(msg, @crc)
  end
end
