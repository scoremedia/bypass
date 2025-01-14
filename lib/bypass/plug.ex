defmodule Bypass.Plug do
  @moduledoc false

  @behaviour Plug

  @impl true
  def init(bypass_instance: pid), do: pid

  @impl true
  def call(%{method: method, request_path: request_path} = conn, pid) do
    route = Bypass.Instance.call(pid, {:get_route, method, request_path})

    case Bypass.Instance.call(pid, {:get_expect_fun, route}) do
      {:ok, ref, fun} ->
        try do
          fun.(conn)
        else
          conn ->
            put_result(pid, route, ref, :ok_call)
            conn
        catch
          class, reason ->
            stacktrace = __STACKTRACE__
            put_result(pid, route, ref, {:exit, {class, reason, stacktrace}})
            :erlang.raise(class, reason, stacktrace)
        end

      {:error, error, route} ->
        put_result(pid, route, make_ref(), {:error, error, route})
        raise "route error"
    end
  end

  defp put_result(pid, route, ref, result) do
    Bypass.Instance.cast(pid, {:put_expect_result, route, ref, result})
  end
end
