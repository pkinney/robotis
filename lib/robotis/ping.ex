defmodule Robotis.Ping do
  @moduledoc false
  require Logger
  alias Robotis.{Comm, Utils}

  @type ping_response() :: %{
          id: byte(),
          model_number: non_neg_integer(),
          model: atom(),
          firmware: byte()
        }

  @type result() :: {:ok, ping_response()} | {:error | any()}

  @spec decode_many(list(Comm.result())) :: list(result())
  def decode_many([]), do: []
  def decode_many([resp | rest]), do: [decode(resp) | decode_many(rest)]

  @spec decode(Comm.result()) :: result()
  def decode({:ok, <<p1, p2, p3>>, id}) do
    model_number = Utils.decode_int(<<p1, p2>>)

    {:ok,
     %{
       id: id,
       model_number: model_number,
       model: model_number_to_model(model_number),
       firmware: p3
     }}
  end

  def decode({:ok, _, _}), do: {:error, :bad_ping}
  def decode(err), do: err

  defp model_number_to_model(350), do: :xl320
  defp model_number_to_model(1200), do: :xl330_m288
  defp model_number_to_model(1190), do: :xl330_m077
  defp model_number_to_model(_), do: :unknown
end
