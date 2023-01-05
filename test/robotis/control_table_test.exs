defmodule Robotis.ControlTableTest do
  use ExUnit.Case
  use ExUnitProperties

  alias Robotis.ControlTable

  test "encode and decode shutdown" do
    check all shutdown <- integer(0..63) do
      flags =
        <<shutdown>>
        |> ControlTable.decode_shutdown()

      assert flags
             |> ControlTable.encode_shutdown()
             |> ControlTable.decode_shutdown() ==
               flags
    end
  end
end
