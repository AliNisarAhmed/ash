defmodule Ash.Type do
  @array_constraints [
    min_length: [
      type: :non_neg_integer,
      doc: "A minimum length for the items"
    ],
    max_length: [
      type: :non_neg_integer,
      doc: "A maximum length for the items"
    ],
    nil_items?: [
      type: :boolean,
      doc: "Whether or not the list can contain nil items",
      default: false
    ]
  ]

  @short_names [
    map: Ash.Type.Map,
    term: Ash.Type.Term,
    atom: Ash.Type.Atom,
    string: Ash.Type.String,
    integer: Ash.Type.Integer,
    float: Ash.Type.Float,
    duration_name: Ash.Type.DurationName,
    function: Ash.Type.Function,
    boolean: Ash.Type.Boolean,
    uuid: Ash.Type.UUID,
    binary: Ash.Type.Binary,
    date: Ash.Type.Date,
    time: Ash.Type.Time,
    decimal: Ash.Type.Decimal,
    ci_string: Ash.Type.CiString,
    naive_datetime: Ash.Type.NaiveDatetime,
    utc_datetime: Ash.Type.UtcDatetime,
    utc_datetime_usec: Ash.Type.UtcDatetimeUsec,
    url_encoded_binary: Ash.Type.UrlEncodedBinary
  ]

  @doc_array_constraints Keyword.put(@array_constraints, :items,
                           type: :any,
                           doc:
                             "Constraints for the elements of the list. See the contained type's docs for more."
                         )
  @moduledoc """
  Describes how to convert data to `Ecto.Type` and eventually into the database.

  This behaviour is a superset of the `Ecto.Type` behavior, that also contains
  API level information, like what kinds of filters are allowed.

  ## Built in types

  #{Enum.map_join(@short_names, fn {key, module} -> "* `#{inspect(key)}` - `#{inspect(module)}`\n" end)}

  ### Composite Types

  Currently, the only composite type supported is a list type, specified via:
  `{:array, Type}`. The constraints available are:

  #{Spark.OptionsHelpers.docs(@doc_array_constraints)}

  ## Defining Custom Types

  Generally you add `use Ash.Type` to your module (it is possible to add `@behaviour
  Ash.Type` and define everything yourself, but this is more work and error-prone).

  Overriding the `{:array, type}` behavior. By definining the `*_array` versions
  of `cast_input`, `cast_stored`, `dump_to_native` and `apply_constraints`, you can
  override how your type behaves as a collection. This is how the features of embedded
  resources are implemented. No need to implement them unless you wish to override the
  default behavior.

  Simple example of a float custom type

  ```Elixir
  defmodule GenTracker.AshFloat do
    use Ash.Type

    @impl Ash.Type
    def storage_type, do: :float

    @impl Ash.Type
    def cast_input(value, _) do
      Ecto.Type.cast(:float, value)
    end

    @impl Ash.Type
    def cast_stored(value, _) do
      Ecto.Type.load(:float, value)
    end

    @impl Ash.Type
    def dump_to_native(value, _) do
      Ecto.Type.dump(:float, value)
    end
  end
  ```

  All the Ash built-in types are implemented with `use Ash.Type` so they are good
  examples to look at to create your own `Ash.Type`
  """

  @type constraints :: Keyword.t()
  @type constraint_error :: String.t() | {String.t(), Keyword.t()}
  @type t :: atom | {:array, atom}
  @type error :: :error | {:error, String.t() | Keyword.t()}

  @callback storage_type() :: Ecto.Type.t()
  @doc """
  Useful for typed data layers (like ash_postgres) to instruct them not to attempt to cast input values.

  You generally won't need this, but it can be an escape hatch for certain cases.
  """
  @callback cast_in_query?() :: boolean
  @callback ecto_type() :: Ecto.Type.t()
  @callback cast_input(term, constraints) ::
              {:ok, term} | error()
  @callback cast_input_array(list(term), constraints) :: {:ok, list(term)} | error()
  @callback cast_stored(term, constraints) :: {:ok, term} | error()
  @callback cast_stored_array(list(term), constraints) ::
              {:ok, list(term)} | error()
  @callback dump_to_native(term, constraints) :: {:ok, term} | error()
  @callback dump_to_native_array(list(term), constraints) :: {:ok, term} | error()
  @callback dump_to_embedded(term, constraints) :: {:ok, term} | :error
  @callback dump_to_embedded_array(list(term), constraints) :: {:ok, term} | error()
  @callback handle_change(old_term :: term, new_term :: term, constraints) ::
              {:ok, term} | error()
  @callback handle_change_array(old_term :: list(term), new_term :: list(term), constraints) ::
              {:ok, term} | error()
  @callback prepare_change(old_term :: term, new_uncasted_term :: term, constraints) ::
              {:ok, term} | error()
  @callback prepare_change_array(
              old_term :: list(term),
              new_uncasted_term :: list(term),
              constraints
            ) ::
              {:ok, term} | error()
  @callback constraints() :: constraints()
  @callback array_constraints() :: constraints()
  @callback apply_constraints(term, constraints) ::
              {:ok, new_value :: term}
              | :ok
              | {:error, constraint_error() | list(constraint_error)}
  @callback apply_constraints_array(list(term), constraints) ::
              {:ok, new_values :: list(term)}
              | :ok
              | {:error, constraint_error() | list(constraint_error)}
  @callback describe(constraints()) :: String.t() | nil
  @callback equal?(term, term) :: boolean
  @callback embedded?() :: boolean
  @callback generator(constraints) :: Enumerable.t()

  @optional_callbacks [
    cast_stored_array: 2,
    generator: 1,
    cast_input_array: 2,
    dump_to_native_array: 2,
    handle_change_array: 3,
    prepare_change_array: 3,
    apply_constraints_array: 2,
    array_constraints: 0,
    dump_to_embedded: 2,
    dump_to_embedded_array: 2
  ]

  @builtin_types Keyword.values(@short_names)

  @doc false
  def builtin_types do
    @short_names
  end

  def builtin?(type) when type in @builtin_types, do: true
  def builtin?(_), do: false

  def embedded_type?({:array, type}) do
    embedded_type?(type)
  end

  def embedded_type?(type) do
    type.embedded?()
  end

  def describe(type, constraints) do
    case get_type(type) do
      {:array, type} ->
        type.describe(constraints)

      type ->
        type.describe(constraints)
    end
  end

  def array_constraints({:array, type}) do
    [items: array_constraints(type)]
  end

  def array_constraints(type) do
    if ash_type?(type) do
      type.array_constraints()
    else
      []
    end
  end

  @spec get_type(atom | module | {:array, atom | module}) ::
          atom | module | {:array, atom | module}
  def get_type({:array, value}) do
    {:array, get_type(value)}
  end

  def get_type(value) when is_atom(value) do
    case Keyword.fetch(@short_names, value) do
      {:ok, mod} -> mod
      :error -> value
    end
  end

  def get_type(value) do
    value
  end

  @spec generator(
          module | {:array, module},
          constraints
        ) :: Enumerable.t()
  def generator(type, constraints) do
    do_generator(type, constraints)
  end

  defp do_generator({:array, type}, constraints) do
    generator = do_generator(type, constraints[:items] || [])

    generator =
      if constraints[:nil_items?] do
        StreamData.one_of([StreamData.constant(nil), generator])
      else
        generator
      end

    StreamData.list_of(generator, Keyword.take(constraints, [:max_length, :min_length]))
  end

  defp do_generator(type, constraints) do
    type = get_type(type)

    if function_exported?(type, :generator, 1) do
      type.generator(constraints)
    else
      raise "generator/1 unimplemented for #{inspect(type)}"
    end
  end

  @doc """
  Process the old casted values alongside the new casted values.

  This is leveraged by embedded types to know if something is being updated
  or destroyed. This is not called on creates.
  """
  def handle_change({:array, type}, old_value, new_value, constraints) do
    if is_atom(type) && :erlang.function_exported(type, :handle_change_array, 3) do
      type.handle_change_array(old_value, new_value, constraints)
    else
      {:ok, new_value}
    end
  end

  def handle_change(type, old_value, new_value, constraints) do
    type.handle_change(old_value, new_value, constraints)
  end

  @doc """
  Process the old casted values alongside the new *un*casted values.

  This is leveraged by embedded types to know if something is being updated
  or destroyed. This is not called on creates.
  """
  def prepare_change({:array, type}, old_value, new_value, constraints) do
    if is_atom(type) && :erlang.function_exported(type, :prepare_change_array, 3) do
      type.prepare_change_array(old_value, new_value, constraints)
    else
      {:ok, new_value}
    end
  end

  def prepare_change(type, old_value, new_value, constraints) do
    type.prepare_change(old_value, new_value, constraints)
  end

  @doc """
  Returns the *underlying* storage type (the underlying type of the *ecto type* of the *ash type*)
  """
  @spec storage_type(t()) :: Ecto.Type.t()
  def storage_type({:array, type}), do: {:array, type.storage_type()}
  def storage_type(type), do: type.storage_type()

  @doc """
  Returns the ecto compatible type for an Ash.Type.

  If you `use Ash.Type`, this is created for you. For builtin types
  this may return a corresponding ecto builtin type (atom)
  """
  @spec ecto_type(t) :: Ecto.Type.t()
  def ecto_type({:array, type}), do: {:array, ecto_type(type)}

  for {name, mod} <- @short_names do
    def ecto_type(unquote(name)), do: ecto_type(unquote(mod))
  end

  def ecto_type(type) do
    type.ecto_type()
  end

  def ash_type_option(type) do
    type = get_type(type)

    if ash_type?(type) do
      {:ok, type}
    else
      {:error, "Attribute type must be a built in type or a type module, got: #{inspect(type)}"}
    end
  end

  @spec ash_type?(term) :: boolean
  @doc "Returns true if the value is a builtin type or adopts the `Ash.Type` behaviour"
  def ash_type?({:array, value}), do: ash_type?(value)

  def ash_type?(module) when is_atom(module) do
    case Code.ensure_compiled(module) do
      {:module, _} ->
        ash_type_module?(module)

      _ ->
        false
    end
  end

  def ash_type?(_), do: false

  @doc """
  Casts input (e.g. unknown) data to an instance of the type, or errors

  Maps to `Ecto.Type.cast/2`
  """
  @spec cast_input(t(), term, constraints | nil) :: {:ok, term} | {:error, Keyword.t()} | :error
  def cast_input(type, term, constraints \\ [])

  def cast_input({:array, type}, empty, constraints) when empty in [nil, ""],
    do: cast_input({:array, type}, [], constraints)

  def cast_input({:array, _type}, term, _) when not (is_list(term) or is_map(term)) do
    {:error, "is invalid"}
  end

  def cast_input({:array, type}, term, constraints) do
    term =
      if is_map(term) do
        term
        |> Enum.sort_by(&elem(&1, 1))
        |> Enum.map(&elem(&1, 0))
      else
        term
      end

    if is_atom(type) && :erlang.function_exported(type, :cast_input_array, 2) do
      type.cast_input_array(term, constraints)
    else
      single_constraints = constraints[:items] || []

      term
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, casted} ->
        case cast_input(type, item, single_constraints) do
          :error ->
            {:halt, {:error, message: "invalid value at %{index}", index: index}}

          {:error, keyword} ->
            errors =
              keyword
              |> List.wrap()
              |> Ash.Error.flatten_preserving_keywords()
              |> Enum.map(fn
                message when is_binary(message) ->
                  [message: message, index: index]

                keyword ->
                  Keyword.put(keyword, :index, index)
              end)

            {:halt, {:error, errors}}

          {:ok, value} ->
            {:cont, {:ok, [value | casted]}}
        end
      end)
    end
  end

  def cast_input(_, nil, _), do: {:ok, nil}

  def cast_input(type, %type{__metadata__: _} = value, _), do: {:ok, value}

  def cast_input(type, term, constraints) do
    type = get_type(type)

    case type.cast_input(term, constraints) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        case term do
          "" ->
            cast_input(type, nil, constraints)

          _ ->
            {:error, "is invalid"}
        end

      {:error, other} ->
        case term do
          "" ->
            cast_input(type, nil, constraints)

          _ ->
            {:error, other}
        end
    end
  end

  @doc """
  Casts a value from the data store to an instance of the type, or errors

  Maps to `Ecto.Type.load/2`
  """
  @spec cast_stored(t(), term, constraints | nil) :: {:ok, term} | {:error, keyword()} | :error
  def cast_stored(type, term, constraints \\ [])

  def cast_stored({:array, type}, term, constraints) do
    if is_atom(type) && :erlang.function_exported(type, :cast_stored_array, 2) do
      type.cast_stored_array(term, constraints)
    else
      if is_nil(term) do
        {:ok, nil}
      else
        term
        |> Enum.with_index()
        |> Enum.reverse()
        |> Enum.reduce_while({:ok, []}, fn {item, index}, {:ok, casted} ->
          single_constraints = constraints[:items] || []

          case cast_stored(type, item, single_constraints) do
            :error ->
              {:halt, {:error, index: index}}

            {:error, keyword} ->
              errors =
                keyword
                |> List.wrap()
                |> Ash.Error.flatten_preserving_keywords()
                |> Enum.map(fn
                  string when is_binary(string) ->
                    [message: string, index: index]

                  vars ->
                    Keyword.put(vars, :index, index)
                end)

              {:halt, {:error, errors}}

            {:ok, value} ->
              {:cont, {:ok, [value | casted]}}
          end
        end)
      end
    end
  end

  def cast_stored(type, term, constraints) do
    type = get_type(type)
    type.cast_stored(term, constraints)
  end

  @doc """
  Confirms if a casted value matches the provided constraints.
  """
  @spec apply_constraints(t(), term, constraints()) :: {:ok, term} | {:error, String.t()}
  def apply_constraints({:array, type}, term, constraints) when is_list(term) do
    if is_atom(type) && :erlang.function_exported(type, :apply_constraints_array, 2) do
      case type.apply_constraints_array(term, constraints) do
        :ok -> {:ok, term}
        other -> other
      end
    else
      list_constraint_errors = list_constraint_errors(term, constraints)

      case list_constraint_errors do
        [] ->
          nil_items? = Keyword.get(constraints, :nil_items?, true)
          item_constraints = constraints[:items] || []

          if item_constraints != [] || !nil_items? do
            term
            |> Enum.with_index()
            |> Enum.reduce({[], []}, fn {item, index}, {items, errors} ->
              if is_nil(item) && not nil_items? do
                {[item | items], [[message: "no nil values", index: index] | errors]}
              else
                case apply_constraints(type, item, item_constraints) do
                  {:ok, value} ->
                    {[value | items], errors}

                  {:error, new_errors} ->
                    new_errors =
                      new_errors
                      |> List.wrap()
                      |> Ash.Error.flatten_preserving_keywords()
                      |> Enum.map(fn
                        string when is_binary(string) ->
                          [message: string, index: index]

                        vars ->
                          Keyword.put(vars, :index, index)
                      end)

                    {[item | items], List.wrap(new_errors) ++ errors}
                end
              end
            end)
            |> case do
              {terms, []} ->
                {:ok, Enum.reverse(terms)}

              {_, errors} ->
                {:error, errors}
            end
          else
            {:ok, term}
          end

        errors ->
          {:error, errors}
      end
    end
  end

  def apply_constraints({:array, _}, _, _) do
    {:error, ["must be a list"]}
  end

  def apply_constraints(type, term, constraints) do
    type = get_type(type)

    if ash_type?(type) do
      case type.apply_constraints(term, constraints) do
        :ok -> {:ok, term}
        other -> other
      end
    else
      {:ok, term}
    end
  end

  defp list_constraint_errors(term, constraints) do
    length =
      if Keyword.has_key?(constraints, :max_length) || Keyword.has_key?(constraints, :min_length) do
        length(term)
      else
        0
      end

    constraints
    |> Enum.reduce([], fn
      {:min_length, min_length}, errors ->
        if length < min_length do
          [message: "must have %{min} or more items", min: min_length]
        else
          errors
        end

      {:max_length, max_length}, errors ->
        if length > max_length do
          [message: "must have %{max} or fewer items", max: max_length]
        else
          errors
        end

      _, errors ->
        errors
    end)
  end

  @spec constraints(Ash.Changeset.t() | Ash.Query.t(), Ash.Type.t(), Keyword.t()) :: Keyword.t()
  def constraints(source, type, constraints) do
    type = get_type(type)

    if embedded_type?(type) do
      Keyword.put(constraints, :__source__, source)
    else
      constraints
    end
  end

  @spec constraints(t()) :: constraints()
  def constraints({:array, _type}) do
    @array_constraints
  end

  def constraints(type) do
    if ash_type?(type) do
      type.constraints()
    else
      []
    end
  end

  def cast_in_query?(type) do
    if ash_type?(type) do
      type.cast_in_query?()
    else
      false
    end
  end

  @doc """
  Casts a value from the Elixir type to a value that the data store can persist

  Maps to `Ecto.Type.dump/2`
  """
  @spec dump_to_native(t(), term, constraints | nil) :: {:ok, term} | {:error, keyword()} | :error
  def dump_to_native(type, term, constraints \\ [])

  def dump_to_native({:array, type}, term, constraints) do
    if is_atom(type) && :erlang.function_exported(type, :dump_to_native_array, 2) do
      type.dump_to_native_array(term, constraints)
    else
      single_constraints = constraints[:items] || []

      term
      |> Enum.reverse()
      |> Enum.reduce_while({:ok, []}, fn item, {:ok, dumped} ->
        case dump_to_native(type, item, single_constraints) do
          :error ->
            {:halt, :error}

          {:ok, value} ->
            {:cont, {:ok, [value | dumped]}}
        end
      end)
    end
  end

  def dump_to_native(type, term, constraints) do
    type = get_type(type)
    type.dump_to_native(term, constraints)
  end

  @doc """
  Casts a value from the Elixir type to a value that can be embedded in another data structure.

  Embedded resources expect to be stored in JSON, so this allows things like UUIDs to be stored
  as strings in embedded resources instead of binary.
  """
  @spec dump_to_embedded(t(), term, constraints | nil) ::
          {:ok, term} | {:error, keyword()} | :error
  def dump_to_embedded(type, term, constraints \\ [])

  def dump_to_embedded({:array, type}, term, constraints) do
    if is_atom(type) && :erlang.function_exported(type, :dump_to_embedded_array, 2) do
      type.dump_to_embedded_array(term, constraints)
    else
      if is_nil(term) do
        {:ok, nil}
      else
        single_constraints = constraints[:items] || []

        term
        |> Enum.reverse()
        |> Enum.reduce_while({:ok, []}, fn item, {:ok, dumped} ->
          case dump_to_embedded(type, item, single_constraints) do
            :error ->
              {:halt, :error}

            {:ok, value} ->
              {:cont, {:ok, [value | dumped]}}
          end
        end)
      end
    end
  end

  def dump_to_embedded(type, term, constraints) do
    type = get_type(type)

    if :erlang.function_exported(type, :dump_to_embedded, 2) do
      type.dump_to_embedded(term, constraints)
    else
      type.dump_to_native(term, constraints)
    end
  end

  @doc """
  Determines if two values of a given type are equal.

  Maps to `Ecto.Type.equal?/3`
  """
  @spec equal?(t(), term, term) :: boolean
  def equal?({:array, type}, [nil | xs], [nil | ys]), do: equal?({:array, type}, xs, ys)

  def equal?({:array, type}, [x | xs], [y | ys]),
    do: equal?(type, x, y) && equal?({:array, type}, xs, ys)

  def equal?({:array, _}, [], []), do: true
  def equal?({:array, _}, _, _), do: false

  def equal?(type, left, right) do
    type.equal?(left, right)
  end

  # @callback equal?(term, term) :: boolean

  defmacro __using__(opts) do
    quote location: :keep, generated: true do
      @behaviour Ash.Type

      parent = __MODULE__

      defmodule EctoType do
        @moduledoc false
        use Ecto.ParameterizedType

        @parent parent

        @impl true
        def init(opts) do
          constraints = @parent.constraints()

          Keyword.take(opts, Keyword.keys(constraints))
        end

        @impl true
        def type(_) do
          @parent.storage_type()
        end

        @impl true
        def cast(term, params) do
          @parent.cast_input(term, params)
        end

        @impl true
        def load(term, _, params) do
          parent = @parent

          case parent.cast_stored(term, params) do
            {:ok, value} ->
              {:ok, value}

            _ ->
              :error
          end
        end

        @impl true
        def dump(term, _dumper, params) do
          parent = @parent

          case parent.dump_to_native(term, params) do
            {:ok, value} ->
              {:ok, value}

            _ ->
              :error
          end
        end

        @impl true
        def equal?(left, right, _params) do
          @parent.equal?(left, right)
        end

        @impl true
        def embed_as(_, _), do: :self
      end

      @impl true
      def ecto_type, do: EctoType

      @impl true
      def equal?(left, right), do: left == right

      @impl true
      def constraints, do: []

      @impl true
      def describe([]), do: String.trim_leading(inspect(__MODULE__), "Ash.Type.")

      def describe(constraints) do
        "#{String.trim_leading(inspect(__MODULE__), "Ash.Type.")} | #{inspect(constraints)}"
      end

      @impl true
      def apply_constraints(_, _), do: :ok

      @impl true
      def cast_in_query?, do: true

      @impl true
      def handle_change(_old_value, new_value, _constraints), do: {:ok, new_value}

      @impl true
      def prepare_change(_old_value, new_value, _constraints), do: {:ok, new_value}

      @impl true
      def array_constraints do
        unquote(@array_constraints)
      end

      @impl true
      def embedded? do
        unquote(opts[:embedded?] || false)
      end

      defoverridable equal?: 2,
                     constraints: 0,
                     array_constraints: 0,
                     apply_constraints: 2,
                     handle_change: 3,
                     prepare_change: 3,
                     cast_in_query?: 0
    end
  end

  defp ash_type_module?(module) do
    Ash.Helpers.implements_behaviour?(module, __MODULE__)
  end
end
