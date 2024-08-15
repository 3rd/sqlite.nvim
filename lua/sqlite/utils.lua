local escape_sql = function(str)
  return "'" .. str:gsub("'", "''") .. "'"
end

return {
  escape_sql_string = escape_sql,
}
