defmodule Robotis do
  @moduledoc """
  Driver for interfacing with Robotis Dynamixel servos.
  """
  use GenServer

  require Logger
  alias Robotis.{Comm, ControlTable, Ping}

  @options ~w(uart_port baud control_table)a

  @type connect() :: %{uart: pid()}
  @type param() :: __MODULE__.ControlTable.param()
  @type servo_id() :: byte()
  @type server() :: atom() | pid()

  @spec ping(server()) :: Ping.result()
  def ping(pid), do: GenServer.call(pid, :ping)

  @spec ping(server(), servo_id()) :: Ping.result()
  def ping(pid, servo), do: GenServer.call(pid, {:ping, servo})

  @spec read(server(), servo_id(), param()) :: {:ok, any()} | {:error, any()}
  def read(pid, servo, param), do: GenServer.call(pid, {:read, servo, param})

  @doc """
  Read a parameter from a servo without applying unit conversion.

  Returns the raw integer value from the servo's control table.
  """
  @spec read_raw(server(), servo_id(), param()) :: {:ok, integer()} | {:error, any()}
  def read_raw(pid, servo, param), do: GenServer.call(pid, {:read_raw, servo, param})

  @spec write(server(), servo_id(), param(), any(), boolean()) :: :ok | {:error, any()}
  def write(pid, servo, param, value, await_status \\ false)

  def write(pid, servo, param, value, false),
    do: GenServer.cast(pid, {:write, servo, param, value})

  def write(pid, servo, param, value, true),
    do: GenServer.call(pid, {:write, servo, param, value})

  @doc """
  Write a raw integer value to a servo parameter without applying unit conversion.

  The value is written directly to the control table register.
  """
  @spec write_raw(server(), servo_id(), param(), integer(), boolean()) :: :ok | {:error, any()}
  def write_raw(pid, servo, param, value, await_status \\ false)

  def write_raw(pid, servo, param, value, false),
    do: GenServer.cast(pid, {:write_raw, servo, param, value})

  def write_raw(pid, servo, param, value, true),
    do: GenServer.call(pid, {:write_raw, servo, param, value})

  @spec factory_reset(server(), servo_id()) :: :ok | {:error, any()}
  def factory_reset(pid, servo), do: GenServer.cast(pid, {:factory_reset, servo})

  @spec reboot(server(), servo_id()) :: :ok | {:error, any()}
  def reboot(pid, servo), do: GenServer.cast(pid, {:reboot, servo})

  @spec clear(server(), servo_id()) :: :ok | {:error, any()}
  def clear(pid, servo), do: GenServer.cast(pid, {:clear, servo})

  @spec sync_write(server(), param(), [{servo_id(), any()}]) :: :ok | {:error, any()}
  def sync_write(pid, param, servos_and_values),
    do: GenServer.cast(pid, {:sync_write, param, servos_and_values})

  @spec fast_sync_read(server(), [servo_id()], param()) ::
          list({servo_id(), {:ok, any()} | {:error, any()}})
  def fast_sync_read(pid, servos, param),
    do: GenServer.call(pid, {:fast_sync_read, servos, param})

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      Keyword.take(opts, @options),
      Keyword.drop(opts, @options)
    )
  end

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :uart_port)
    baud = Keyword.get(opts, :baud, 57_600)
    control_table = Keyword.get(opts, :control_table, :xl330_m288)
    {:ok, connect} = Comm.open(port, baud)

    {:ok, %{connect: connect, control_table: control_table}}
  end

  @impl true
  def handle_call(:ping, _, state) do
    {:reply, Comm.ping(state.connect) |> Enum.map(&Ping.decode/1), state}
  end

  def handle_call({:ping, servo_id}, _, state) do
    {:reply, Comm.ping(state.connect, servo_id) |> Ping.decode(), state}
  end

  def handle_call({:read, servo_id, param}, _, state) do
    {address, length} = ControlTable.address_and_length_for_param(state.control_table, param)

    Comm.read(state.connect, servo_id, address, length)
    |> case do
      {:ok, "", _} ->
        {:reply, {:error, :empty_response}, state}

      {:ok, resp, _} ->
        ControlTable.decode_param(state.control_table, param, resp)
        |> case do
          {:ok, value} -> {:reply, {:ok, value}, state}
          err -> {:reply, err, state}
        end

      e ->
        e
    end
  end

  def handle_call({:read_raw, servo_id, param}, _, state) do
    {address, length} = ControlTable.address_and_length_for_param(state.control_table, param)

    case Comm.read(state.connect, servo_id, address, length) do
      {:ok, "", _} -> {:reply, {:error, :empty_response}, state}
      {:ok, resp, _} -> {:reply, {:ok, Robotis.Utils.decode_int(resp)}, state}
      e -> {:reply, e, state}
    end
  end

  def handle_call({:write, servo_id, param, value}, _, state) do
    ControlTable.encode_param(state.control_table, param, value)
    |> case do
      {:ok, address, bytes} ->
        Comm.write_and_await_status(state.connect, servo_id, address, bytes)

      e ->
        e
    end
    |> case do
      {:ok, "", _} -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:write_raw, servo_id, param, value}, _, state) do
    {address, length} = ControlTable.address_and_length_for_param(state.control_table, param)
    bytes = Robotis.Utils.encode_int(value, length)

    case Comm.write_and_await_status(state.connect, servo_id, address, bytes) do
      {:ok, "", _} -> {:reply, :ok, state}
      {:error, error} -> {:reply, {:error, error}, state}
    end
  end

  def handle_call({:fast_sync_read, servos, param}, _, state) do
    {address, length} = ControlTable.address_and_length_for_param(state.control_table, param)

    resp =
      Comm.fast_sync_read(state.connect, servos, address, length)
      |> Enum.map(fn
        {:ok, id, params} -> {id, ControlTable.decode_param(state.control_table, param, params)}
        {error, id, _} -> {id, {:error, error}}
        e -> e
      end)

    {:reply, resp, state}
  end

  @impl true
  def handle_cast({:write, servo_id, param, value}, state) do
    {:ok, address, bytes} = ControlTable.encode_param(state.control_table, param, value)
    :ok = Comm.write(state.connect, servo_id, address, bytes)
    {:noreply, state}
  end

  def handle_cast({:write_raw, servo_id, param, value}, state) do
    {address, length} = ControlTable.address_and_length_for_param(state.control_table, param)
    bytes = Robotis.Utils.encode_int(value, length)
    :ok = Comm.write(state.connect, servo_id, address, bytes)
    {:noreply, state}
  end

  def handle_cast({:factory_reset, servo_id}, state) do
    :ok = Comm.factory_reset(state.connect, servo_id)
    {:noreply, state}
  end

  def handle_cast({:reboot, servo_id}, state) do
    :ok = Comm.reboot(state.connect, servo_id)
    {:noreply, state}
  end

  def handle_cast({:clear, servo_id}, state) do
    :ok = Comm.clear(state.connect, servo_id)
    {:noreply, state}
  end

  def handle_cast({:sync_write, param, values}, state) do
    {address, length} = ControlTable.address_and_length_for_param(state.control_table, param)

    params =
      values
      |> Enum.map(fn {servo_id, value} ->
        {:ok, _, bytes} = ControlTable.encode_param(state.control_table, param, value)
        {servo_id, bytes}
      end)

    :ok = Comm.sync_write(state.connect, address, length, params)
    {:noreply, state}
  end
end
