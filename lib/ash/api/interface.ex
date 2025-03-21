defmodule Ash.Api.Interface do
  @moduledoc false

  defmacro __using__(_) do
    quote bind_quoted: [], generated: true do
      alias Ash.Api

      def get!(resource, id_or_filter, params \\ []) do
        Ash.Api.Interface.enforce_resource!(resource)

        Api.get!(__MODULE__, resource, id_or_filter, params)
      end

      def get(resource, id_or_filter, params \\ []) do
        Ash.Api.Interface.enforce_resource!(resource)
        Ash.Api.Interface.enforce_keyword_list!(params)

        case Api.get(__MODULE__, resource, id_or_filter, params) do
          {:ok, instance} -> {:ok, instance}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def read!(query, opts \\ [])

      def read!(query, opts) do
        Ash.Api.Interface.enforce_query_or_resource!(query)
        Ash.Api.Interface.enforce_keyword_list!(opts)

        Api.read!(__MODULE__, query, opts)
      end

      def read(query, opts \\ [])

      def read(query, opts) do
        Ash.Api.Interface.enforce_query_or_resource!(query)
        Ash.Api.Interface.enforce_keyword_list!(opts)

        case Api.read(__MODULE__, query, opts) do
          {:ok, results, query} ->
            {:ok, results, query}

          {:ok, results} ->
            {:ok, results}

          {:error, error} ->
            {:error, Ash.Error.to_error_class(error)}
        end
      end

      def read_one!(query, opts \\ [])

      def read_one!(query, opts) do
        Ash.Api.Interface.enforce_query_or_resource!(query)
        Ash.Api.Interface.enforce_keyword_list!(opts)

        Api.read_one!(__MODULE__, query, opts)
      end

      def read_one(query, opts \\ [])

      def read_one(query, opts) do
        Ash.Api.Interface.enforce_query_or_resource!(query)
        Ash.Api.Interface.enforce_keyword_list!(opts)

        case Api.read_one(__MODULE__, query, opts) do
          {:ok, result} -> {:ok, result}
          {:ok, result, query} -> {:ok, result, query}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def page!(page, request) do
        Api.page!(__MODULE__, page, request)
      end

      def page(page, request) do
        case Api.page(__MODULE__, page, request) do
          {:ok, page} -> {:ok, page}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def load!(data, query, opts \\ []) do
        Api.load!(__MODULE__, data, query, opts)
      end

      def load(data, query, opts \\ []) do
        case Api.load(__MODULE__, data, query, opts) do
          {:ok, results} -> {:ok, results}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def create!(changeset, params \\ []) do
        Api.create!(__MODULE__, changeset, params)
      end

      def create(changeset, params \\ []) do
        case Api.create(__MODULE__, changeset, params) do
          {:ok, instance} -> {:ok, instance}
          {:ok, instance, notifications} -> {:ok, instance, notifications}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def update!(changeset, params \\ []) do
        Api.update!(__MODULE__, changeset, params)
      end

      def update(changeset, params \\ []) do
        case Api.update(__MODULE__, changeset, params) do
          {:ok, instance} -> {:ok, instance}
          {:ok, instance, notifications} -> {:ok, instance, notifications}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def destroy!(record, params \\ []) do
        Api.destroy!(__MODULE__, record, params)
      end

      def destroy(record, params \\ []) do
        case Api.destroy(__MODULE__, record, params) do
          :ok -> :ok
          {:ok, result, notifications} -> {:ok, result, notifications}
          {:ok, notifications} -> {:ok, notifications}
          {:error, error} -> {:error, Ash.Error.to_error_class(error)}
        end
      end

      def reload!(%resource{} = record, params \\ []) do
        id = record |> Map.take(Ash.Resource.Info.primary_key(resource)) |> Enum.to_list()
        params = Keyword.put_new(params, :tenant, Map.get(record.__metadata__, :tenant))

        get!(resource, id, params)
      end

      def reload(%resource{} = record, params \\ []) do
        id = record |> Map.take(Ash.Resource.Info.primary_key(resource)) |> Enum.to_list()
        params = Keyword.put_new(params, :tenant, Map.get(record.__metadata__, :tenant))
        get(resource, id, params)
      end
    end
  end

  defmacro enforce_query_or_resource!(query_or_resource) do
    quote generated: true do
      case Ash.Api.Interface.do_enforce_query_or_resource!(unquote(query_or_resource)) do
        :ok ->
          :ok

        _ ->
          {fun, arity} = __ENV__.function
          mfa = "#{inspect(__ENV__.module)}.#{fun}/#{arity}"

          raise "#{mfa} expected an %Ash.Query{} or an Ash Resource but instead got #{inspect(unquote(query_or_resource))}"
      end
    end
  end

  def do_enforce_query_or_resource!(query_or_resource)
  def do_enforce_query_or_resource!(%Ash.Query{}), do: :ok

  def do_enforce_query_or_resource!(resource) when is_atom(resource) do
    if Ash.Resource.Info.resource?(resource), do: :ok, else: :error
  end

  def do_enforce_query_or_resource!(_something), do: :error

  defmacro enforce_resource!(resource) do
    quote generated: true do
      if Ash.Resource.Info.resource?(unquote(resource)) do
        :ok
      else
        {fun, arity} = __ENV__.function
        mfa = "#{inspect(__ENV__.module)}.#{fun}/#{arity}"

        raise Ash.Error.Invalid.NoSuchResource,
          message: "#{mfa} expected an Ash Resource but instead got #{inspect(unquote(resource))}"
      end
    end
  end

  defmacro enforce_keyword_list!(list) do
    quote generated: true do
      if Keyword.keyword?(unquote(list)) do
        :ok
      else
        {fun, arity} = __ENV__.function
        mfa = "#{inspect(__ENV__.module)}.#{fun}/#{arity}"
        raise "#{mfa} expected a keyword list, but instead got #{inspect(unquote(list))}"
      end
    end
  end
end
