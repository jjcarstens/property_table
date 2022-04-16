defmodule PropertyTable do
  @moduledoc File.read!("README.md")
             |> String.split("## Usage")
             |> Enum.fetch!(1)

  alias PropertyTable.Table

  @typedoc """
  A table_id identifies a group of properties
  """
  @type table_id() :: atom()

  @typedoc """
  Properties
  """
  @type property :: [String.t()]
  @type property_with_wildcards :: [String.t() | :_]
  @type value :: any()
  @type property_value :: {property(), value()}

  @type options :: [name: table_id(), properties: [property_value()]]

  @spec start_link(options()) :: {:ok, pid} | {:error, term}
  defdelegate start_link(options), to: PropertyTable.Supervisor

  @doc """
  Returns a specification to start a property_table under a supervisor.
  See `Supervisor`.
  """
  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, PropertyTable),
      start: {PropertyTable, :start_link, [opts]},
      type: :supervisor
    }
  end

  @doc """
  Subscribe to receive events
  """
  @spec subscribe(table_id(), property_with_wildcards()) :: :ok
  def subscribe(table, property) when is_list(property) do
    assert_property_with_wildcards(property)

    registry = PropertyTable.Supervisor.registry_name(table)
    {:ok, _} = Registry.register(registry, :subscriptions, property)

    :ok
  end

  @doc """
  Stop subscribing to a property
  """
  @spec unsubscribe(table_id(), property_with_wildcards()) :: :ok
  def unsubscribe(table, property) when is_list(property) do
    registry = PropertyTable.Supervisor.registry_name(table)
    Registry.unregister(registry, :subscriptions)
  end

  @doc """
  Get the current value of a property
  """
  @spec get(table_id(), property(), value()) :: value()
  def get(table, property, default \\ nil) when is_list(property) do
    assert_property(property)
    Table.get(table, property, default)
  end

  @doc """
  Fetch a property with the time that it was set

  Timestamps come from `System.monotonic_time()`
  """
  @spec fetch_with_timestamp(table_id(), property()) :: {:ok, value(), integer()} | :error
  def fetch_with_timestamp(table, property) when is_list(property) do
    assert_property(property)
    Table.fetch_with_timestamp(table, property)
  end

  @doc """
  Get all properties

  It's possible to pass a prefix to only return properties under a specific path.
  """
  @spec get_all(table_id(), property()) :: [{property(), value()}]
  def get_all(table, prefix \\ []) when is_list(prefix) do
    assert_property(prefix)

    Table.get_all(table, prefix)
  end

  @doc """
  Get a list of all properties matching the specified property pattern
  """
  @spec match(table_id(), property_with_wildcards()) :: [{property(), value()}]
  def match(table, pattern) when is_list(pattern) do
    assert_property_with_wildcards(pattern)

    Table.match(table, pattern)
  end

  @doc """
  Update a property and notify listeners
  """
  @spec put(table_id(), property(), value()) :: :ok
  def put(table, property, value) when is_list(property) do
    Table.put(table, property, value)
  end

  @doc """
  Delete the specified property
  """
  @spec clear(table_id(), property()) :: :ok
  defdelegate clear(table, property), to: Table

  @doc """
  Clear out all properties under a prefix
  """
  @spec clear_all(table_id(), property()) :: :ok
  defdelegate clear_all(table, property), to: Table

  defp assert_property(property) do
    Enum.each(property, fn
      v when is_binary(v) -> :ok
      :_ -> raise ArgumentError, "Wildcards not allowed in this property"
      _ -> raise ArgumentError, "Property should be a list of strings"
    end)
  end

  defp assert_property_with_wildcards(property) do
    Enum.each(property, fn
      v when is_binary(v) -> :ok
      :_ -> :ok
      _ -> raise ArgumentError, "Property should be a list of strings"
    end)
  end
end
