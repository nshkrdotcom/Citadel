defmodule Citadel.Runtime.TracePublisher do
  @moduledoc """
  Best-effort bounded trace publisher used after commit.

  The module is intentionally not wired into the application tree yet. Runtime
  owners can start it explicitly in later waves without redefining the seam.
  """

  use GenServer

  alias Citadel.ObservabilityContract.Telemetry
  alias Citadel.TraceEnvelope

  defmodule Buffer do
    @moduledoc """
    Segmented bounded buffer preserving a protected error-family evidence window.
    """

    alias Citadel.TraceEnvelope

    @type queued_envelope :: {non_neg_integer(), TraceEnvelope.t()}

    @type t :: %__MODULE__{
            total_capacity: pos_integer(),
            protected_capacity: non_neg_integer(),
            regular_capacity: non_neg_integer(),
            protected_queue: :queue.queue(queued_envelope()),
            regular_queue: :queue.queue(queued_envelope()),
            protected_len: non_neg_integer(),
            regular_len: non_neg_integer(),
            next_seq: non_neg_integer()
          }

    defstruct total_capacity: 0,
              protected_capacity: 0,
              regular_capacity: 0,
              protected_queue: :queue.new(),
              regular_queue: :queue.new(),
              protected_len: 0,
              regular_len: 0,
              next_seq: 0

    @spec new!(keyword()) :: t()
    def new!(opts) do
      total_capacity = Keyword.get(opts, :total_capacity, 256)
      protected_capacity = min(Keyword.get(opts, :protected_capacity, 64), total_capacity)
      regular_capacity = total_capacity - protected_capacity

      if total_capacity <= 0 do
        raise ArgumentError, "Citadel.Runtime.TracePublisher buffer total_capacity must be positive"
      end

      %__MODULE__{
        total_capacity: total_capacity,
        protected_capacity: protected_capacity,
        regular_capacity: regular_capacity,
        protected_queue: :queue.new(),
        regular_queue: :queue.new(),
        protected_len: 0,
        regular_len: 0,
        next_seq: 0
      }
    end

    @spec enqueue(t(), TraceEnvelope.t()) :: {t(), TraceEnvelope.t() | nil}
    def enqueue(%__MODULE__{} = buffer, %TraceEnvelope{} = envelope) do
      queued_envelope = {buffer.next_seq, envelope}

      if TraceEnvelope.protected_error_family?(envelope) do
        do_enqueue(buffer, queued_envelope, :protected)
      else
        do_enqueue(buffer, queued_envelope, :regular)
      end
    end

    @spec take_batch(t(), pos_integer()) :: {[TraceEnvelope.t()], t()}
    def take_batch(%__MODULE__{} = buffer, batch_size) when batch_size > 0 do
      do_take_batch(buffer, batch_size, [])
    end

    @spec depth(t()) :: non_neg_integer()
    def depth(%__MODULE__{} = buffer), do: buffer.protected_len + buffer.regular_len

    @spec depths(t()) :: %{depth: non_neg_integer(), protected_depth: non_neg_integer(), regular_depth: non_neg_integer()}
    def depths(%__MODULE__{} = buffer) do
      %{
        depth: depth(buffer),
        protected_depth: buffer.protected_len,
        regular_depth: buffer.regular_len
      }
    end

    defp do_enqueue(%__MODULE__{} = buffer, queued_envelope, :protected) do
      {buffer, dropped} =
        if buffer.protected_len >= buffer.protected_capacity and buffer.protected_capacity > 0 do
          {{:value, {_seq, dropped}}, queue} = :queue.out(buffer.protected_queue)
          {%{buffer | protected_queue: queue, protected_len: buffer.protected_len - 1}, dropped}
        else
          {buffer, nil}
        end

      queue = :queue.in(queued_envelope, buffer.protected_queue)

      {%{
         buffer
         | protected_queue: queue,
           protected_len: buffer.protected_len + 1,
           next_seq: buffer.next_seq + 1
       }, dropped}
    end

    defp do_enqueue(%__MODULE__{} = buffer, queued_envelope, :regular) do
      {buffer, dropped} =
        cond do
          buffer.regular_len >= buffer.regular_capacity and buffer.regular_capacity > 0 ->
            {{:value, {_seq, dropped}}, queue} = :queue.out(buffer.regular_queue)
            {%{buffer | regular_queue: queue, regular_len: buffer.regular_len - 1}, dropped}

          buffer.regular_capacity == 0 and buffer.protected_len > 0 ->
            {{:value, {_seq, dropped}}, queue} = :queue.out(buffer.protected_queue)
            {%{buffer | protected_queue: queue, protected_len: buffer.protected_len - 1}, dropped}

          true ->
            {buffer, nil}
        end

      queue = :queue.in(queued_envelope, buffer.regular_queue)

      {%{
         buffer
         | regular_queue: queue,
           regular_len: buffer.regular_len + 1,
           next_seq: buffer.next_seq + 1
       }, dropped}
    end

    defp do_take_batch(%__MODULE__{} = buffer, 0, acc), do: {Enum.reverse(acc), buffer}
    defp do_take_batch(%__MODULE__{} = buffer, _remaining, acc) when buffer.protected_len == 0 and buffer.regular_len == 0,
      do: {Enum.reverse(acc), buffer}

    defp do_take_batch(%__MODULE__{} = buffer, remaining, acc) do
      {queued_envelope, buffer} = pop_oldest(buffer)
      {_seq, envelope} = queued_envelope
      do_take_batch(buffer, remaining - 1, [envelope | acc])
    end

    defp pop_oldest(%__MODULE__{protected_len: 0, regular_len: regular_len} = buffer) when regular_len > 0 do
      {{:value, queued_envelope}, queue} = :queue.out(buffer.regular_queue)
      {queued_envelope, %{buffer | regular_queue: queue, regular_len: buffer.regular_len - 1}}
    end

    defp pop_oldest(%__MODULE__{regular_len: 0, protected_len: protected_len} = buffer) when protected_len > 0 do
      {{:value, queued_envelope}, queue} = :queue.out(buffer.protected_queue)
      {queued_envelope, %{buffer | protected_queue: queue, protected_len: buffer.protected_len - 1}}
    end

    defp pop_oldest(%__MODULE__{} = buffer) do
      {:value, {protected_seq, _} = protected_head} = :queue.peek(buffer.protected_queue)
      {:value, {regular_seq, _} = regular_head} = :queue.peek(buffer.regular_queue)

      if protected_seq <= regular_seq do
        {{:value, queued_envelope}, queue} = :queue.out(buffer.protected_queue)
        {queued_envelope || protected_head, %{buffer | protected_queue: queue, protected_len: buffer.protected_len - 1}}
      else
        {{:value, queued_envelope}, queue} = :queue.out(buffer.regular_queue)
        {queued_envelope || regular_head, %{buffer | regular_queue: queue, regular_len: buffer.regular_len - 1}}
      end
    end
  end

  @type state :: %{
          trace_port: module(),
          buffer: Buffer.t(),
          batch_size: pos_integer(),
          flush_interval_ms: non_neg_integer(),
          drain_scheduled?: boolean
        }

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    name = Keyword.get(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @spec publish_trace(GenServer.server(), TraceEnvelope.t() | map() | keyword()) :: :ok | {:error, atom()}
  def publish_trace(server, envelope) do
    GenServer.call(server, {:publish_trace, envelope})
  end

  @spec publish_traces(GenServer.server(), [TraceEnvelope.t() | map() | keyword()]) :: :ok | {:error, atom()}
  def publish_traces(server, envelopes) do
    GenServer.call(server, {:publish_traces, envelopes})
  end

  @spec snapshot(GenServer.server()) :: map()
  def snapshot(server), do: GenServer.call(server, :snapshot)

  @impl true
  def init(opts) do
    state = %{
      trace_port: Keyword.get(opts, :trace_port, Citadel.TraceBridge),
      buffer:
        Buffer.new!(
          total_capacity: Keyword.get(opts, :buffer_capacity, 256),
          protected_capacity: Keyword.get(opts, :protected_error_capacity, 64)
        ),
      batch_size: Keyword.get(opts, :batch_size, 20),
      flush_interval_ms: Keyword.get(opts, :flush_interval_ms, 10),
      drain_scheduled?: false
    }

    emit_depth_telemetry(state.buffer)
    {:ok, state}
  end

  @impl true
  def handle_call({:publish_trace, envelope}, _from, state) do
    case TraceEnvelope.new(envelope) do
      {:ok, normalized_envelope} ->
        {state, dropped} = enqueue_envelope(state, normalized_envelope)
        maybe_emit_drop_telemetry(dropped)
        emit_depth_telemetry(state.buffer)
        {:reply, :ok, maybe_schedule_drain(state)}

      {:error, _error} ->
        {:reply, {:error, :invalid_envelope}, state}
    end
  end

  def handle_call({:publish_traces, envelopes}, _from, state) when is_list(envelopes) do
    case Enum.reduce_while(envelopes, {state, []}, fn envelope, {state_acc, dropped_acc} ->
           case TraceEnvelope.new(envelope) do
             {:ok, normalized_envelope} ->
               {state_acc, dropped} = enqueue_envelope(state_acc, normalized_envelope)
               {:cont, {state_acc, [dropped | dropped_acc]}}

             {:error, _error} ->
               {:halt, {:error, :invalid_envelope}}
           end
         end) do
      {:error, :invalid_envelope} ->
        {:reply, {:error, :invalid_envelope}, state}

      {state, dropped} ->
        Enum.each(dropped, &maybe_emit_drop_telemetry/1)
        emit_depth_telemetry(state.buffer)
        {:reply, :ok, maybe_schedule_drain(state)}
    end
  end

  def handle_call(:snapshot, _from, state) do
    {:reply, Buffer.depths(state.buffer), state}
  end

  @impl true
  def handle_info(:drain, state) do
    {batch, buffer} = Buffer.take_batch(state.buffer, state.batch_size)
    state = %{state | buffer: buffer, drain_scheduled?: false}
    emit_depth_telemetry(state.buffer)

    state =
      case batch do
        [] ->
          state

        _batch ->
          case publish_batch(state.trace_port, batch) do
            :ok ->
              state

            {:error, reason_code} ->
              emit_failure_telemetry(reason_code, length(batch))
              state
          end
      end

    {:noreply, maybe_schedule_drain(state)}
  end

  defp enqueue_envelope(state, envelope) do
    {buffer, dropped} = Buffer.enqueue(state.buffer, envelope)
    {%{state | buffer: buffer}, dropped}
  end

  defp maybe_schedule_drain(%{drain_scheduled?: true} = state), do: state

  defp maybe_schedule_drain(%{buffer: buffer} = state) do
    if Buffer.depth(buffer) > 0 do
      Process.send_after(self(), :drain, state.flush_interval_ms)
      %{state | drain_scheduled?: true}
    else
      state
    end
  end

  defp publish_batch(trace_port, [envelope]) do
    trace_port.publish_trace(envelope)
  end

  defp publish_batch(trace_port, batch) do
    if function_exported?(trace_port, :publish_traces, 1) do
      trace_port.publish_traces(batch)
    else
      Enum.reduce_while(batch, :ok, fn envelope, :ok ->
        case trace_port.publish_trace(envelope) do
          :ok -> {:cont, :ok}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
    end
  end

  defp emit_depth_telemetry(buffer) do
    :telemetry.execute(
      Telemetry.event_name(:trace_buffer_depth),
      Buffer.depths(buffer),
      %{}
    )
  end

  defp emit_failure_telemetry(reason_code, batch_size) do
    :telemetry.execute(
      Telemetry.event_name(:trace_publication_failure),
      %{count: 1, batch_size: batch_size},
      %{reason_code: reason_code}
    )
  end

  defp maybe_emit_drop_telemetry(nil), do: :ok

  defp maybe_emit_drop_telemetry(%TraceEnvelope{} = dropped) do
    :telemetry.execute(
      Telemetry.event_name(:trace_publication_drop),
      %{count: 1},
      %{
        dropped_family: dropped.family,
        dropped_family_classification: TraceEnvelope.family_classification(dropped)
      }
    )
  end
end
