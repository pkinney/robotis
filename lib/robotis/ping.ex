defmodule Robotis.Ping do
  require Logger
  alias Robotis.{Comm, Utils}

  @type ping_response() :: %{
          id: byte(),
          model_number: non_neg_integer(),
          model: atom(),
          firmware: byte()
        }

  @spec ping(Robotis.connect()) :: [{:ok, __MODULE__.ping_response()}]
  def ping(connect) do
    Comm.ping(connect)
    |> Enum.map(&decode_ping/1)
    |> Enum.map(fn
      {:ok, a} -> a
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec ping(Robotis.connect(), byte()) :: {:ok, __MODULE__.ping_response()} | {:error, any()}
  def ping(connect, id) do
    Comm.ping(connect, id) |> decode_ping()
  end

  defp decode_ping({:ok, <<p1, p2, p3>>, id, 0x55}) do
    model_number = Utils.decode_int(<<p1, p2>>)

    {:ok,
     %{
       id: id,
       model_number: model_number,
       model: model_number_to_model(model_number),
       firmware: p3
     }}
  end

  defp decode_ping({:ok, _, _, _}), do: {:error, :bad_ping}
  defp decode_ping(err), do: err

  defp model_number_to_model(350), do: :xl320
  defp model_number_to_model(1200), do: :xl330_m288
  defp model_number_to_model(1190), do: :xl330_m077
  defp model_number_to_model(_), do: :unknown
end
