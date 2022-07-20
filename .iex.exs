defmodule X do
  def d(name) when is_atom(name) do
    {^name, bin, _filename} = :code.get_object_code(name)
    decompile_binary(bin)
  end

  def d({:module, _name, bin, _names}) do
    decompile_binary(bin)
  end

  def decompile_binary(bin) do
    bin
    |> :beam_lib.chunks([:abstract_code])
    |> elem(1) |> elem(1)
    |> get_in([:abstract_code])
    |> elem(1)
    |> :erl_syntax.form_list |> :erl_prettypr.format
    |> IO.puts
  end
end
