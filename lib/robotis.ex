defmodule Robotis do
  use GenServer

  require Logger
  alias Robotis.{Comm, Servo, Ping}

  @options ~w(uart_port baud)a

  @default_servo_config %{
    reverse: false,
    profile: :velocity_based,
    min_angle_limit: 0.0,
    max_angle_limit: 360.0
  }
  @poll_interval 10

  @type connect() :: %{uart: pid()}
  @type param() :: __MODULE__.ControlTable.param()
  @type servo_id() :: byte()

  def enumerate_servos(), do: GenServer.call(__MODULE__, :enumerate_servos)

  @spec ping(servo_id()) :: __MODULE__.Ping.ping_response()
  def ping(servo), do: GenServer.call(__MODULE__, {:ping, servo})

  @spec read(servo_id(), param()) :: {:ok, any()} | {:error, any()}
  def read(servo, param), do: GenServer.call(__MODULE__, {:read, servo, param})

  @spec write(servo_id(), param(), any(), boolean()) :: :ok | {:error, any()}
  def write(servo, param, value, await_status \\ false)

  def write(servo, param, value, false),
    do: GenServer.cast(__MODULE__, {:write, servo, param, value})

  def write(servo, param, value, true),
    do: GenServer.call(__MODULE__, {:write, servo, param, value})

  @spec factory_reset(servo_id()) :: :ok | {:error, any()}
  def factory_reset(servo), do: GenServer.cast(__MODULE__, {:factory_reset, servo})

  @spec reboot(servo_id()) :: :ok | {:error, any()}
  def reboot(servo), do: GenServer.cast(__MODULE__, {:reboot, servo})

  @spec clear(servo_id()) :: :ok | {:error, any()}
  def clear(servo), do: GenServer.cast(__MODULE__, {:clear, servo})

  @spec sync_write(param(), [{servo_id(), any()}]) ::
          list({servo_id(), param(), :ok | {:error, any()}})
  def sync_write(param, servos_and_values),
    do: GenServer.call(__MODULE__, {:sync_write, param, servos_and_values})

  @spec fast_sync_read([servo_id()], param()) ::
          list({servo_id(), {:ok, any()} | {:error, any()}})
  def fast_sync_read(servos, param),
    do: GenServer.call(__MODULE__, {:fast_sync_read, servos, param})

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(
      __MODULE__,
      Keyword.take(opts, @options),
      Keyword.drop(opts, @options) ++ [name: __MODULE__]
    )
  end

  @impl true
  def init(opts) do
    port = Keyword.fetch!(opts, :uart_port)
    baud = Keyword.get(opts, :baud, 57_600)
    servos = Keyword.get(opts, :servos, %{})
    {:ok, connect} = Comm.open(port, baud)

    {:ok, %{connect: connect, servos: servos}}
  end

  @impl true
  def handle_call({:ping, servo_id}, _, state) do
    {:reply, Ping.ping(state.connect, servo_id), state}
  end
end
