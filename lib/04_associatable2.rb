require_relative '03_associatable'
require 'byebug'

# Phase IV
module Associatable
  # Remember to go back to 04_associatable to write ::assoc_options

  def has_one_through(name, through_name, source_name)
    through_options = assoc_options[through_name]   #in case of cat/human/house, gives human's association options
    through_table = through_options.table_name

    define_method("#{name}") do
      #scope is cat instance
      source_options = through_options.model_class.assoc_options[source_name]
      source_table = source_options.table_name

      data = DBConnection.execute(<<-SQL)
        SELECT
          #{source_table}.*
        FROM
          #{source_table}
        JOIN
          #{through_table} ON #{through_table}.#{source_options.foreign_key} = #{source_table}.#{source_options.primary_key}
        WHERE
          #{through_table}.#{through_options.primary_key} = #{self.send(through_options.foreign_key)}
      SQL

      source_options.model_class.new(data.first)
    end
  end
end
