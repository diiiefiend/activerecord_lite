require_relative 'db_connection'
require_relative 'sql_object'

module Searchable
  def where(params)
    where_line = params.keys.map { |key| "#{key} = ?" }.join(" AND ")

    data = DBConnection.execute(<<-SQL, *params.values)
      SELECT * FROM #{table_name} WHERE #{where_line}
    SQL

    data.map { |obj| self.new(obj) }
  end
end

class SQLObject
  extend Searchable
end
