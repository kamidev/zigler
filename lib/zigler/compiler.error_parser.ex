defmodule Zigler.Compiler.ErrorParser do
  import NimbleParsec

  @numbers [?0..?9]

  errormsg =
    ascii_string([not: ?:], min: 1)
    |> ignore(string(":"))
    |> ascii_string(@numbers, min: 1)
    |> ignore(string(":"))
    |> ascii_string(@numbers, min: 1)
    |> ignore(string(":"))
    |> ascii_string([0..255], min: 1)

  defparsec :parse_error, errormsg

  def parse(msg, code_dir, tmp_dir) do
    {:ok, [path, line, _col, msg], _, _, _, _} = parse_error(msg)

    file_line = String.to_integer(line)

    # check if we need full translation or just file translation.
    if Path.basename(path) == "zig_nif.zig" do
      # read the actual path file
      file_content = File.read!(path)

      {offset, true_file, original_line} = file_content
      |> parse_line_comments
      |> Enum.filter(fn {a, _, _} -> a <= file_line end)
      |> List.last

      true_line = file_line - offset + original_line

      %CompileError{
        file: true_file,
        line: true_line,
        description: String.trim(msg)
      }
    else
      rel_path = Path.relative_to(path, tmp_dir)
      %CompileError{
        file: Path.join(code_dir, rel_path),
        line: String.to_integer(line),
        description: String.trim(msg)
      }
    end
  end

  line_comment =
    repeat(ascii_char([0..255]) |> lookahead_not(string("//")))
    |> ascii_char([0..255])
    |> string("// ")
    |> concat(ascii_string([not: ?\s], min: 1) |> tag(:file))
    |> string(" line: ")
    |> concat(ascii_string(@numbers, min: 1) |> tag(:line))
    |> repeat(ascii_char([?\s]))
    |> string("\n")
    |> post_traverse(:parse_group)

  if Mix.env == :test do
    # TODO: tests on parameters
    defparsec :parse_line_comment, line_comment
  end

  line =
    utf8_string([not: ?\n], min: 1)
    |> string("\n")

  empty_line = string("\n")

  by_line =
    repeat(choice([
      line_comment,
      line,
      empty_line
    ]))

  defparsec :by_line_comments, by_line

  defp parse_group(_rest, content, context, {line, _}, _) do
    kw = Enum.flat_map(content, fn
      {:file, [file]} -> [{:file, file}]
      {:line, [line]} -> [{:line, String.to_integer(line)}]
      _ -> []
    end)
    {[{:group, {line, kw[:file], kw[:line]}}], context}
  end

  # read our instrumented comments to try to find the location of the error.
  defp parse_line_comments(txt) do
    {:ok, parsed, _, _, _, _} = by_line_comments(txt)

    parsed
    |> Enum.flat_map(fn
      {:group, data} -> [data]
      _ -> []
    end)
  end


end