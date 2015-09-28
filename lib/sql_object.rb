require_relative 'db_connection'
require 'active_support/inflector'

class SQLObject
  def self.columns
    cols = DBConnection.execute2("SELECT * FROM #{table_name}")[0]
    cols.map(&:to_sym)
  end

  def self.finalize!
    columns.each do |column|
      define_method(column) do
        attributes[column]
      end
      define_method(column.to_s + "=") do |value|
        attributes[column] = value
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    return @table_name if @table_name

    self.name.tableize
  end

  def self.all
    data = DBConnection.execute(<<-SQL)
      SELECT * FROM #{table_name}
    SQL

    parse_all(data)
  end

  def self.parse_all(results)
    results.map { |params| self.new(params) }
  end

  def self.find(id)
    data = DBConnection.execute(<<-SQL, id)
      SELECT * FROM #{table_name} WHERE id = ?
    SQL

    data.empty? ? nil : self.new(data[0])
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_sym = attr_name.to_sym
      raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_sym)
      send("#{attr_name}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.class.columns.map { |col| send("#{col}") }
  end

  def insert
    col_names = self.class.columns.join(", ")
    questions_marks = (["?"] * self.class.columns.length).join(", ")

    data = DBConnection.execute(<<-SQL, *attribute_values)
      INSERT INTO
        #{self.class.table_name} (#{col_names})
      VALUES
        (#{questions_marks})
    SQL

    self.id = DBConnection.last_insert_row_id
  end

  def update
    set_values = self.class.columns.map {|col| "#{col} = ?"}.join(", ")
    data = DBConnection.execute(<<-SQL, *attribute_values, id)
      UPDATE
        #{self.class.table_name}
      SET
        #{set_values}
      WHERE
        id = ?
    SQL
  end

  def save
    id.nil? ? insert : update
  end
end
