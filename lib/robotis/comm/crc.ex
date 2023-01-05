defmodule Robotis.Comm.CRC do
  import Bitwise

  @crc [:code.priv_dir(:robotis), "crc.bin"]
       |> Path.join()
       |> File.read!()
       |> :erlang.binary_to_term()

  def append_crc(msg) do
    msg <> (msg |> crc() |> encode_crc())
  end

  def validate_crc(packet) do
    body_size = byte_size(packet) - 2
    <<body::binary-size(body_size), crc::binary-size(2)>> = packet

    if crc == crc(body) |> encode_crc() do
      {:ok, body}
    else
      {:error, :invalid_crc}
    end
  end

  def valid_crc?(body, crc) do
    crc == crc(body) |> encode_crc()
  end

  defp crc(msg) do
    msg
    |> :binary.bin_to_list()
    |> Enum.reduce(0, fn j, acc ->
      i = bxor(acc >>> 8, j) &&& 0xFF
      bxor(acc <<< 8, @crc |> Enum.at(i))
    end) &&&
      0xFFFF
  end

  defp encode_crc(i) do
    <<i &&& 0xFF, i >>> 8 &&& 0xFF>>
  end
end
