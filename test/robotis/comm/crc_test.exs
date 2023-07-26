defmodule Robotis.Comm.CRCTest do
  use ExUnit.Case

  alias Robotis.Comm.CRC

  # See https://emanual.robotis.com/docs/en/dxl/protocol2/#ping-instruction-packet-1
  @test_body <<0xFF, 0xFF, 0xFD, 0x00, 0xFE, 0x03, 0x00, 0x01>>
  @test_packet @test_body <> <<0x31, 0x42>>

  test "appends correct CRC" do
    assert CRC.append_crc(@test_body) == @test_packet
  end

  test "validates CRCs" do
    assert CRC.validate_crc(@test_packet) == {:ok, @test_body}

    corrupt_packet = @test_body <> <<0x30, 0x42>>
    assert CRC.validate_crc(corrupt_packet) == {:error, :invalid_crc}
  end
end
