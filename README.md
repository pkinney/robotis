# Robotis

![Build Status](https://github.com/pkinney/robotis/actions/workflows/ci.yaml/badge.svg)
[![Hex.pm](https://img.shields.io/hexpm/v/robotis.svg)](https://hex.pm/packages/robotis)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/robotis)

Driver for interfacing with Robotis Dynamixel servos.

This is a work in progress and currently supports XL320, XL330, and XM430 series servos. It only speaks Dynamixel protocol v2.

While it is possible to support GPIO-based switching for converting UART to the half-duplex signal required by Dynamixel, this library works best
speaking UART over USB to another device that can do that conversion (such as and [OpenR150](https://www.robotis.us/openrb-150-starter-kit/) running
the `usb_to_dynamixel` sketch.

## Installation

```elixir
def deps do
  [
    {:robotis, "~> 0.2.0"}
  ]
end
```

## Usage

```elixir
{:ok, pid} = Robotis.start_link(uart_port: "ttyAMA0", baud: 1_000_000, control_table: Robotis.ControlTable.XL330)

Robotis.ping(pid, 1) # => {:ok, %{firmware: 49, id: 1, model: :xl330_m288, model_number: 1200}}
Robotis.read(pid, 1, :present_position) # => {:ok, 14.58984375}
:ok = Robotis.write(pid, 1, :torque_enable, true)
:ok = Robotis.write(pid, 1, :goal_position, 124.293)

```

## Control Tables

This library uses control tables to define the registers available on different Dynamixel models.
Currently, the library contains the following control tables:

- `Robotis.ControlTable.XL320`
- `Robotis.ControlTable.XL330`
- `Robotis.ControlTable.XM430`

You can also define your own control tables by creating a module that implements the `Robotis.ControlTable` behaviour and defines the necessary registers.

````elixir


## Write or Write-and-Wait

The `Robotis.write/5` function can work in either a write or write-and-wait manner:

```elixir
# The default, this will send the command to the servo and not wait for a
# response.
:ok = Robotis.write(pid, 1, :goal_position, 180)

# This will send the command and wait for a status packet from the servo. This
# will block until that status packet is received or a timeout occurs
:ok = Robotis.write(pid, 1, :goal_position, 180, true)

````

It's important to consider the setting of `:status_return_level` when deciding which to use. In the case that `:status_return_level` is set
to `:all`, the servo will respond with a status message after the write. If the Robotis.write call is not expecting this and another command
is issued, it's possible the status message and the new command will conflict and have unintended consequences.

```elixir
# The following may receive no data or invalid packets when reading present_position
:ok = Robotis.write(pid, 1, :status_return_level, :all)
:ok = Robotis.write(pid, 1, :goal_position, 180)
:ok = Robotis.read(pid, 1, :present_position)

# The following will work
:ok = Robotis.write(pid, 1, :status_return_level, :ping_read)
:ok = Robotis.write(pid, 1, :goal_position, 180)
:ok = Robotis.read(pid, 1, :present_position)
```
