defmodule DistributedPerformanceAnalyzer.Domain.UseCase.LoadStepUseCase do
  @moduledoc """
  Load step use case
  """

  alias DistributedPerformanceAnalyzer.Domain.Model.{LoadProcess, Step}

  alias DistributedPerformanceAnalyzer.Domain.UseCase.{
    ConnectionPoolUseCase,
    LoadGeneratorUseCase
  }

  def start_step(step_model = %Step{}) do
    # TODO: Agregar timeout y manejar errores remotos
    node_list = [Node.self() | Node.list()]
    loads = distribute_load(node_list, step_model.concurrency)
    node_count = Enum.count(node_list)
    IO.puts("Starting with #{inspect(node_count)} nodes")

    Enum.zip(node_list, loads)
    |> Enum.map(fn {node, load} ->
      IO.puts("Starting with #{inspect(node)} and #{inspect(load)}")
      :rpc.async_call(node, __MODULE__, :start_step_local, [step_model, load])
    end)
    |> Enum.map(&:rpc.yield/1)
  end

  def distribute_load(node_list, concurrency) do
    node_count = Enum.count(node_list)
    per_node = div(concurrency, node_count)

    node_list
    |> Enum.map(fn _ -> per_node end)
    |> add_rem([], rem(concurrency, node_count))
  end

  def add_rem(loads, added, to_add) do
    case loads do
      [x | xs] when to_add > 0 -> add_rem(xs, added ++ [x + 1], to_add - 1)
      [x | xs] -> add_rem(xs, added ++ [x], to_add)
      _ -> added
    end
  end

  def start_step_local(
        step_model = %Step{
          execution_model: execution_model,
          name: name,
          step_number: _a
        },
        concurrency
      ) do
    ConnectionPoolUseCase.ensure_capacity(concurrency)
    {:ok, launch_config} = LoadProcess.new(step_model)

    loads =
      1..concurrency
      |> Enum.map(fn _ -> start_load(launch_config, execution_model.dataset, concurrency) end)
      |> Enum.map(fn ref -> wait_for(ref, execution_model.duration + 1000) end)

    ended_loads = Enum.filter(loads, fn x -> x == :load_end end) |> Enum.count()
    timeout_loads = Enum.filter(loads, fn x -> x == :load_timeout end) |> Enum.count()

    IO.puts(
      "#{ended_loads} Processes completed, and #{timeout_loads} Processes timeout for step: #{name}"
    )
  end

  defp start_load(launch_config, dataset, concurrency) do
    {:ok, pid} = LoadGeneratorUseCase.start(launch_config, dataset, concurrency)
    Process.monitor(pid)
  end

  defp wait_for(ref, timeout) do
    receive do
      {:DOWN, ^ref, _, _, _} -> :load_end
    after
      timeout -> :load_timeout
    end
  end
end
