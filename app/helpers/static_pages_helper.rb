module StaticPagesHelper
  # @return [String] where the first H1 in the given Markdown is removed.
  def _remove_markdown_h1(str)
    str.sub(/(?:\A(\s*\n)?|\n\s*\n)# .*/, "\n").sub(/(?:\A(\s*\n)?|(\n)\s*\n)\S[^\n]*\n===*\n/m, '\1\2'+"\n")
  end
end

