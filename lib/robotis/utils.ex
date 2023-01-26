defmodule Robotis.Utils do
  @moduledoc false
  import Bitwise

  def encode_boolean(true), do: <<1>>
  def encode_boolean(false), do: <<0>>
  def encode_int(i, 1), do: <<i &&& 0xFF>>
  def encode_int(i, 2), do: <<i &&& 0xFF, i >>> 8 &&& 0xFF>>
  def encode_int(i, 4), do: <<i &&& 0xFF, i >>> 8 &&& 0xFF, i >>> 16 &&& 0xFF, i >>> 24 &&& 0xFF>>

  def decode_boolean(<<0x00>>), do: false
  def decode_boolean(_), do: true
  def decode_int(<<a, 0::1, b::7>>), do: a + (b <<< 8)
  def decode_int(<<a, b>>), do: -decode_int(<<bxor(a, 0xFF), bxor(b, 0xFF)>>)
  def decode_int(<<a, b, c, 0::1, d::7>>), do: a + (b <<< 8) + (c <<< 16) + (d <<< 24)

  def decode_int(<<a, b, c, d>>),
    do: -decode_int(<<bxor(a, 0xFF), bxor(b, 0xFF), bxor(c, 0xFF), bxor(d, 0xFF)>>)
end
