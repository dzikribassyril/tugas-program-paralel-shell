function Header(header)
  if header.level == 2 and pandoc.utils.stringify(header.content):match('^7%.') then
    return {pandoc.RawBlock('latex', '\\clearpage'), header}
  end
end

function Table(table)
  return {pandoc.RawBlock('latex', '\\needspace{10\\baselineskip}'), table}
end
