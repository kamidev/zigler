defmodule Zig.Return do
  @moduledoc false

  @enforce_keys ~w[type cleanup]a
  defstruct @enforce_keys ++ [as: :default]

  alias Zig.Type

  @type t :: %__MODULE__{
          type: Type.t(),
          cleanup: boolean,
          as: :binary | :list | :default
        }

  @type opts :: [:noclean | :binary | :list | {:cleanup, boolean} | {:as, :binary | :list}]

  def new(type, options) do
    struct!(__MODULE__, [type: type] ++ normalize_options(type, options))
  end

  @as ~w[binary list]a
  @options ~w[as cleanup]a

  defp normalize_options(type, options) do
    options
    |> List.wrap()
    |> Enum.map(fn
      option when option in @as -> {:as, option}
      :noclean -> {:cleanup, false}
      {k, _} = kv when k in @options -> kv
    end)
    |> Keyword.put_new(:cleanup, Type.can_cleanup?(type))
  end

  def render(return) do
    Type.render_return(return.type, return)
  end
end