defmodule Citadel.TestSupport.ToxiproxyHarness do
  @moduledoc false

  @api_url System.get_env("CITADEL_TOXIPROXY_API", "http://127.0.0.1:18474")
  @proxy_name "citadel_nginx"
  @proxy_port 18081
  @proxy_upstream "toxiproxy-upstream:80"

  def availability_result!(suite_name) do
    if System.get_env("CITADEL_REQUIRE_TOXIPROXY") == "1" do
      if available?() do
        :ok
      else
        raise """
        #{suite_name} requires the verified Citadel toxiproxy harness.
        Run `dev/docker/toxiproxy/verify.sh` from /home/home/p/g/n/citadel before rerunning.
        """
      end
    else
      {:skip,
       "#{suite_name} runs only under Wave 12 harness mode; use `CITADEL_REQUIRE_TOXIPROXY=1`."}
    end
  end

  def available? do
    case request(:get, "/version", nil) do
      {:ok, {_status, _headers, body}} -> String.trim(body) != ""
      {:error, _reason} -> false
    end
  end

  def ensure_proxy!(opts \\ []) do
    name = Keyword.get(opts, :name, @proxy_name)
    listen_port = Keyword.get(opts, :listen_port, @proxy_port)
    upstream = Keyword.get(opts, :upstream, @proxy_upstream)

    case fetch_proxy(name) do
      {:ok, _proxy} ->
        :ok

      {:error, :not_found} ->
        request_json!(
          :post,
          "/proxies",
          %{
            name: name,
            listen: "0.0.0.0:#{listen_port}",
            upstream: upstream,
            enabled: true
          }
        )

      {:error, reason} ->
        raise "failed to fetch toxiproxy proxy #{inspect(name)}: #{inspect(reason)}"
    end

    reset!()
    set_enabled!(name, true)
  end

  def reset! do
    _ = request_json!(:post, "/reset", %{})
    :ok
  end

  def fetch_proxy(name \\ @proxy_name) do
    case request_json(:get, "/proxies/#{name}", nil) do
      {:ok, {_status, _headers, proxy}} -> {:ok, proxy}
      {:error, {:http_status, 404, _body}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def set_enabled!(name \\ @proxy_name, enabled) when is_boolean(enabled) do
    _ = request_json!(:post, "/proxies/#{name}", %{enabled: enabled})
    :ok
  end

  def add_toxic!(name, toxic_name, type, attributes, opts \\ []) do
    _ =
      request_json!(
        :post,
        "/proxies/#{name}/toxics",
        %{
          name: toxic_name,
          type: type,
          stream: Keyword.get(opts, :stream, "downstream"),
          toxicity: Keyword.get(opts, :toxicity, 1.0),
          attributes: attributes
        }
      )

    :ok
  end

  def proxy_url(path \\ "/", opts \\ []) do
    port = Keyword.get(opts, :port, @proxy_port)
    "http://127.0.0.1:#{port}#{path}"
  end

  def request_url(method, url, opts \\ []) when method in [:get, :post] and is_binary(url) do
    timeout = Keyword.get(opts, :timeout, 500)
    connect_timeout = Keyword.get(opts, :connect_timeout, timeout)
    headers = Keyword.get(opts, :headers, [])
    body = Keyword.get(opts, :body, "")
    content_type = Keyword.get(opts, :content_type, "application/json")

    args =
      [
        "--silent",
        "--show-error",
        "--request",
        String.upcase(to_string(method)),
        "--connect-timeout",
        format_curl_seconds(connect_timeout),
        "--max-time",
        format_curl_seconds(timeout),
        "--output",
        "/dev/null",
        "--write-out",
        "%{http_code}"
      ] ++
        curl_headers(headers) ++
        curl_body(method, content_type, body) ++
        [url]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {http_code, 0} ->
        {:ok, {{~c"HTTP/1.1", String.to_integer(String.trim(http_code)), ~c"OK"}, [], ""}}

      {_output, 7} ->
        {:error, {:failed_connect, :curl}}

      {_output, 28} ->
        {:error, :timeout}

      {_output, code} when code in [52, 56] ->
        {:error, :socket_closed_remotely}

      {output, _code} ->
        {:error, {:curl, output}}
    end
  end

  def normalize_http_result({:ok, {{_http_version, status, _reason}, _headers, _body}}, receipt_ref)
      when status in 200..299 and is_binary(receipt_ref) do
    {:ok, receipt_ref}
  end

  def normalize_http_result({:ok, {{_http_version, _status, _reason}, _headers, _body}}, _receipt_ref) do
    {:error, :backend_rejected}
  end

  def normalize_http_result({:error, reason}, _receipt_ref) do
    {:error, normalize_http_error(reason)}
  end

  def normalize_http_error(:timeout), do: :timeout
  def normalize_http_error(:socket_closed_remotely), do: :connection_dropped
  def normalize_http_error({:failed_connect, _details}), do: :unavailable
  def normalize_http_error({:shutdown, _details}), do: :unavailable
  def normalize_http_error({:connect_timeout, _details}), do: :timeout
  def normalize_http_error(_reason), do: :unknown

  def measure_ms(fun) when is_function(fun, 0) do
    started_at = System.monotonic_time(:millisecond)
    result = fun.()
    elapsed_ms = System.monotonic_time(:millisecond) - started_at
    {result, elapsed_ms}
  end

  defp request_json(method, path, body) do
    with {:ok, {status, headers, response_body}} <- request(method, path, body),
         {:ok, decoded_body} <- decode_body(status, response_body) do
      {:ok, {status, headers, decoded_body}}
    end
  end

  defp request_json!(method, path, body) do
    case request_json(method, path, body) do
      {:ok, {_status, _headers, decoded_body}} ->
        decoded_body

      {:error, reason} ->
        raise "toxiproxy API request failed for #{method} #{path}: #{inspect(reason)}"
    end
  end

  defp request(method, path, body) when method in [:get, :post] do
    url = @api_url <> path

    args =
      [
        "--silent",
        "--show-error",
        "--request",
        String.upcase(to_string(method)),
        "--connect-timeout",
        format_curl_seconds(1_000),
        "--max-time",
        format_curl_seconds(1_000),
        "--write-out",
        "\n%{http_code}"
      ] ++
        curl_body(method, "application/json", JSON.encode!(body || %{})) ++
        [url]

    case System.cmd("curl", args, stderr_to_stdout: true) do
      {output, 0} ->
        {response_body, status} = split_status_line(output)
        {:ok, {status, [], response_body}}

      {output, code} ->
        {:error, {:curl, code, output}}
    end
  end

  defp decode_body(status, body) when status in 200..299 do
    case String.trim(body) do
      "" -> {:ok, %{}}
      other -> {:ok, JSON.decode!(other)}
    end
  end

  defp decode_body(status, body), do: {:error, {:http_status, status, body}}

  defp curl_headers(headers) do
    Enum.flat_map(headers, fn
      {name, value} -> ["--header", "#{name}: #{value}"]
      other -> raise ArgumentError, "unsupported curl header: #{inspect(other)}"
    end)
  end

  defp curl_body(:get, _content_type, _body), do: []

  defp curl_body(:post, content_type, body) do
    ["--header", "Content-Type: #{content_type}", "--data", IO.iodata_to_binary(body)]
  end

  defp split_status_line(output) do
    output = String.trim_trailing(output)
    lines = String.split(output, "\n")
    status = lines |> List.last() |> String.to_integer()
    response_body = lines |> Enum.drop(-1) |> Enum.join("\n")
    {response_body, status}
  end

  defp format_curl_seconds(milliseconds) when is_integer(milliseconds) do
    seconds = milliseconds / 1_000
    :erlang.float_to_binary(seconds, decimals: 3)
  end
end

defmodule Citadel.TestSupport.HalfOpenSocketServer do
  @moduledoc false

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  def url(server) do
    port = GenServer.call(server, :port)
    "http://127.0.0.1:#{port}/"
  end

  @impl true
  def init(_opts) do
    {:ok, listener} =
      :gen_tcp.listen(0, [
        :binary,
        packet: :raw,
        active: false,
        reuseaddr: true,
        exit_on_close: false
      ])

    {:ok, {_ip, port}} = :inet.sockname(listener)
    parent = self()

    acceptor =
      Task.async(fn ->
        accept_loop(parent, listener)
      end)

    {:ok, %{listener: listener, port: port, acceptor: acceptor, sockets: []}}
  end

  @impl true
  def handle_call(:port, _from, state) do
    {:reply, state.port, state}
  end

  @impl true
  def handle_info({:accepted, socket}, state) do
    {:noreply, %{state | sockets: [socket | state.sockets]}}
  end

  @impl true
  def terminate(_reason, state) do
    Enum.each(state.sockets, &:gen_tcp.close/1)
    :gen_tcp.close(state.listener)
    :ok
  end

  defp accept_loop(parent, listener) do
    case :gen_tcp.accept(listener) do
      {:ok, socket} ->
        send(parent, {:accepted, socket})

        Task.start(fn ->
          _ = :gen_tcp.recv(socket, 0, 250)
          Process.sleep(:infinity)
        end)

        accept_loop(parent, listener)

      {:error, :closed} ->
        :ok
    end
  end
end
