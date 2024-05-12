use Protoss

defprotocol Zig.Type do
  alias Zig.Type.Array
  alias Zig.Type.Bool
  alias Zig.Type.Cpointer
  alias Zig.Type.Error
  alias Zig.Type.Float
  alias Zig.Type.Integer
  alias Zig.Type.Manypointer
  alias Zig.Type.Optional
  alias Zig.Type.Slice
  alias Zig.Type.Struct
  alias Zig.Type.Resource

  @type t ::
          Array.t()
          | Bool.t()
          | Cpointer.t()
          | Error.t()
          | Zig.Type.Enum.t()
          | Float.t()
          | Integer.t()
          | ManyPointer.t()
          | Optional.t()
          | Slice.t()
          | Struct.t()
          | :void
          | :anyopaque_pointer
          | :env
          | :pid
          | :port
          | :term
          | :erl_nif_term
          | :erl_nif_binary
          | :erl_nif_event
          | :erl_nif_binary_pointer
          | :stacktrace

  @spec marshal_param(t, Macro.t(), non_neg_integer, :elixir | :erlang) :: Macro.t()
  def marshal_param(type, variable_ast, index, platform)

  @spec marshal_return(t, Macro.t(), Elixir | :erlang) :: Macro.t()
  def marshal_return(type, variable_ast, platform)

  # validations:

  @spec param_allowed?(t) :: boolean
  def param_allowed?(type)

  @spec return_allowed?(t) :: boolean
  def return_allowed?(type)

  @spec can_cleanup?(t) :: boolean
  def can_cleanup?(type)

  # rendered zig code:
  @spec render_payload_options(t, non_neg_integer, boolean) :: iodata
  def render_payload_options(type, index, error_info?)

  @spec render_return(t, Return.t()) :: iodata
  def render_return(type, return)

  @spec render_zig(t) :: String.t()
  def render_zig(type)

  @typep spec_context :: :param | :return
  @spec render_elixir_spec(t, spec_context, keyword) :: Macro.t()
  def render_elixir_spec(type, context, opts)
after
  defmacro sigil_t({:<<>>, _, [string]}, _) do
    string
    |> parse
    |> Macro.escape()
  end

  def parse(string) do
    case string do
      "u" <> _ ->
        Integer.parse(string)

      "i" <> _ ->
        Integer.parse(string)

      "f" <> _ ->
        Float.parse(string)

      "c_uint" <> _ ->
        Integer.parse(string)

      "[]" <> rest ->
        Slice.of(parse(rest))

      "[:0]" <> rest ->
        Slice.of(parse(rest), has_sentinel?: true)

      "[*]" <> rest ->
        Manypointer.of(parse(rest))

      "[*:0]" <> rest ->
        Manypointer.of(parse(rest), has_sentinel?: true)

      "[*c]" <> rest ->
        Cpointer.of(parse(rest))

      "?" <> rest ->
        Optional.of(parse(rest))

      "[" <> maybe_array ->
        case Elixir.Integer.parse(maybe_array) do
          {count, "]" <> rest} ->
            Array.of(parse(rest), count)

          {count, ":0]" <> rest} ->
            Array.of(parse(rest), count, has_sentinel?: true)

          _ ->
            raise "unknown type #{string}"
        end

      "?*.cimport" <> rest ->
        if String.ends_with?(rest, "struct_enif_environment_t") do
          Env
        else
          unknown =
            rest
            |> String.split(".")
            |> List.last()

          raise "unknown type #{unknown}"
        end
    end
  end

  @pointer_types ~w(array struct)

  def from_json(json, module) do
    case json do
      nil ->
        # only allow during documentation sema passes
        if module do
          raise CompileError, description: "zigler encountered anytype"
        else
          :anytype
        end

      %{"type" => "unusable:" <> typename} ->
        # only allow during documentation sema passes
        if module do
          raise CompileError, description: "zigler encountered the unusable type #{typename}"
        else
          String.to_atom(typename)
        end

      %{"type" => "bool"} ->
        Bool.from_json(json)

      %{"type" => "void"} ->
        :void

      %{"type" => "integer"} ->
        Integer.from_json(json)

      %{"type" => "enum"} ->
        Zig.Type.Enum.from_json(json, module)

      %{"type" => "float"} ->
        Float.from_json(json)

      %{
        "type" => "struct",
        "fields" => [%{"name" => "__payload"}, %{"name" => "__should_release"}]
      } ->
        Resource.from_json(json, module)

      %{"type" => "struct"} ->
        Struct.from_json(json, module)

      %{"type" => "array"} ->
        Array.from_json(json, module)

      %{"type" => "slice"} ->
        Slice.from_json(json, module)

      %{"type" => "pointer", "child" => child = %{"type" => type}} when type in @pointer_types ->
        child
        |> __MODULE__.from_json(module)
        |> Map.replace!(:mutable, true)

      %{"type" => "pointer", "child" => %{"type" => "unusable:anyopaque"}} ->
        :anyopaque_pointer

      %{"type" => "manypointer"} ->
        Manypointer.from_json(json, module)

      %{"type" => "cpointer"} ->
        Cpointer.from_json(json, module)

      %{"type" => "optional"} ->
        Optional.from_json(json, module)

      %{"type" => "error"} ->
        Error.from_json(json, module)

      %{"type" => "env"} ->
        :env

      %{"type" => "erl_nif_term"} ->
        :erl_nif_term

      %{"type" => "struct", "name" => "beam.term"} ->
        :term

      %{"type" => "pid"} ->
        :pid

      %{"type" => "port"} ->
        :port

      %{"type" => "term"} ->
        :term

      %{"type" => "e.ErlNifBinary"} ->
        :erl_nif_binary

      %{"type" => "e.ErlNifEvent"} ->
        :erl_nif_event

      %{"type" => "pointer", "child" => %{"type" => "e.ErlNifBinary"}} ->
        :erl_nif_binary_pointer

      %{"type" => "pointer", "child" => %{"type" => "builtin.StackTrace"}} ->
        :stacktrace
    end
  end

  def needs_make?(:erl_nif_term), do: false
  def needs_make?(:term), do: false
  def needs_make?(_), do: true

  # defaults

  def _default_payload_options, do: ".{.error_info = &error_info},"

  def _default_return(option \\ nil)

  def _default_return(%{as: type}),
    do: "break :result_block beam.make(result, .{.as = .#{type}}).v;"

  def _default_return(_), do: "break :result_block beam.make(result, .{}).v;"

  def _default_marshal, do: []
end

defimpl Zig.Type, for: Atom do
  alias Zig.Type

  def param_allowed?(type), do: type in ~w(term erl_nif_term pid)a
  def return_allowed?(type), do: type in ~w(term erl_nif_term pid void)a
  def can_cleanup?(_), do: false

  def render_zig(:term), do: "beam.term"
  def render_zig(:erl_nif_term), do: "e.erl_nif_term"
  def render_zig(:pid), do: "beam.pid"
  def render_zig(:env), do: "beam.env"
  def render_zig(atom), do: "#{atom}"

  def render_return(:void, _), do: "_ = result; break :result_block beam.make(.ok, .{}).v;"
  def render_return(_, _), do: Type._default_return()

  def render_payload_options(:erl_nif_term, _, _), do: ".{},"
  def render_payload_options(:term, _, _), do: ".{},"

  def render_payload_options(type, _, _)
      when type in ~w[env stacktrace erl_nif_binary erl_nif_event erl_nif_binary_pointer]a,
      do: raise("unreachable")

  def render_payload_options(_, _, _), do: Type._default_payload_options()

  def render_elixir_spec(:void, :return, _), do: :ok

  def render_elixir_spec(:pid, _, _) do
    quote do 
      pid()
    end
  end

  def render_elixir_spec(term, _, _) when term in ~w(term erl_nif_term)a do
    quote do
      term()
    end
  end

  def marshal_param(_, _, _, _), do: Type._default_marshal()
  def marshal_return(_, _, _), do: Type._default_marshal()
end
