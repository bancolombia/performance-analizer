defmodule DistributedPerformanceAnalyzer.Infrastructure.Adapters.OutputCsv do
  @moduledoc """
  Print outgoing report file in csv format
  """
  alias DistributedPerformanceAnalyzer.Utils.DataTypeUtils
  require Logger

  @spec save_csv(any(), String.t(), String.t(), boolean()) :: {:ok}
  def save_csv(data, file_name, header, print) do
    {:ok, file} = File.open(file_name, [:write])

    if print do
      IO.puts("####CSV#######")
      IO.puts(header)
    end

    IO.binwrite(file, header <> "\n")

    data
    |> Stream.map(fn row ->
      if print do
        IO.puts(row)
      end

      row <> "\n"
    end)
    |> Stream.into(File.stream!(file_name))
    |> Stream.run()
  end
end
