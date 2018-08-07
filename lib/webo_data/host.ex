defmodule WeboData.Host do

  # use Webo.Util.Box

  alias Webo.Data.InfluxConnection, as: Influx

  defmodule Disk.Series do
    use Instream.Series

    series do
      database    "webo"
      measurement "host.disk"

      tag         :host_name
      tag         :volume

      field       :"size:mb"
      field       :"used:mb"
    end
  end

  defmodule Cpu.Series do
    use Instream.Series

    series do
      database    "webo"
      measurement "host.cpu"

      tag         :host_name

      field       :"load_average_1min:int"
      field       :"load_average_5min:int"
      field       :"load_average_15min:int"
      field       :"nprocs:int"
    end
  end

  defmodule Memory.Series do
    use Instream.Series

    series do
      database    "webo"
      measurement "host.memory"

      tag         :host_name

      field       :"mem_total:bytes"
      field       :"mem_allocated:bytes"
      field       :"greediest_process:pid"
      field       :"greediest_process_allocated:bytes"
    end
  end

  @doc """

      | Measurement | Tags      | Values                        |
      |-------------|-----------|-------------------------------|
      |             |           |                               |
      | host.disk   | host_name | size:kb                       |
      |             | volume    | used:kb                       |
      |             |           |                               |

  """

  def fetch_and_store_host_disk(host, host_and_node) do
    case :rpc.call(host_and_node, :disksup, :get_disk_data, []) do
      { :badrpc, reason } ->
        IO.inspect reason, pretty: true
        { :no_data }
      [{ 'none', 0, 0 }] ->
        { :no_data }
      diskdata when is_list(diskdata) ->
        diskdata
        |> Enum.map(&disk_data_to_point(host, &1))
        |> Influx.write()
    end
  end

  defp disk_data_to_point(host, { id, size, used }) do
    data = %Disk.Series{}
    %{ data |
            tags:   %{ data.tags   | host_name: host, volume: id },
            fields: %{ data.fields | "size:mb": div(size + 512, 1024), "used:mb": div(used + 512, 1024) }
    }
  end


  @doc """
      |-------------|-----------|-------------------------------|
      |             |           |                               |
      | host.cpu    | host_name | load_average_1min:int         |
      |             |           | load_average_5min:int         |
      |             |           | load_average_15min:int        |
      |             |           | nprocs:int                    |
      |             |           |                               |
      |-------------|-----------|-------------------------------|
  """
  def fetch_and_store_host_cpu(host, host_and_node) do

    [ nprocs, avg1, avg5, avg15 ] =
        [ :nprocs, :avg1, :avg5, :avg15 ]
        |> Enum.map(&zero_arity_rpc(host_and_node, :cpu_sup, &1))

    cpu_data_to_point(host, nprocs, avg1, avg5, avg15)
    |> Influx.write()
    |> IO.inspect
  end

  defp cpu_data_to_point(host, nprocs, avg1, avg5, avg15) do
    data = %Cpu.Series{}
    %{ data | tags:   %{ data.tags   | host_name: host },
              fields: %{ data.fields | "nprocs:int":             nprocs,
                                       "load_average_1min:int":  avg1,
                                       "load_average_5min:int":  avg5,
                                       "load_average_15min:int": avg15
                      }
   }
  end

  defp zero_arity_rpc(host, m, f, default \\ 0) do
    case :rpc.call(host, m, f, []) do
      { :badrpc, reason } ->
        IO.inspect reason, pretty: true
        default
      value ->
        value
    end
  end


  @doc """
      |-------------|-----------|-------------------------------|
      |             |           |                               |
      | host.memory | host_name | mem_total:bytes           |
      |             |           | mem_allocated:bytes                |
      |             |           | greediest_process:pid         |
      |             |           | greediest_process_used:bytes  |
      |-------------|-----------|-------------------------------|
  """

  def fetch_and_store_host_memory(host, host_and_node) do

    { total, allocated, worst } = :rpc.call(host_and_node, :memsup, :get_memory_data, [])

    memory_data_to_point(host, host_and_node, total, allocated, worst)
    |> Influx.write()
  end

  defp memory_data_to_point(host, host_and_node, total, allocated, :undefined ) do
    memory_data_to_point(host, host_and_node, total, allocated, { nil, nil })
  end

  defp memory_data_to_point(host, _host_and_node, total, allocated, { pid, used }) when is_binary(pid) do
    data = %Memory.Series{}
    %{ data
           | tags:   %{ data.tags   | host_name: host },
             fields: %{ data.fields |
                               "mem_total:bytes":                   total,
                               "mem_allocated:bytes":               allocated,
                               "greediest_process:pid":             pid,
                               "greediest_process_allocated:bytes": used
                      }
   }
  end


  defp memory_data_to_point(host, host_and_node, total, allocated, { pid, used }) when is_pid(pid) do
    pid = :rpc.call(host_and_node, Process, :info, [pid])[:registered_name] || pid
    memory_data_to_point(host, host_and_node,  total, allocated, { inspect(pid), used })
  end


end
