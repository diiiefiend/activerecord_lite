require_relative 'searchable'
require 'active_support/inflector'

class AssocOptions
  attr_accessor(
    :foreign_key,
    :class_name,
    :primary_key
  )

  def model_class
    @class_name.constantize
  end

  def table_name
    model_class.table_name
  end
end

class BelongsToOptions < AssocOptions
  def initialize(name, options = {})
    @foreign_key = options[:foreign_key] || "#{name.to_s}_id".to_sym
    @primary_key = options[:primary_key] || :id
    @class_name = options[:class_name] || name.to_s.camelcase
  end
end

class HasManyOptions < AssocOptions
  def initialize(name, self_class_name, options = {})
    @foreign_key = options[:foreign_key] || "#{self_class_name.downcase.singularize}_id".to_sym
    @primary_key = options[:primary_key] || :id
    @class_name = options[:class_name] || name.to_s.singularize.camelcase
  end
end

module Associatable
  def belongs_to(name, options = {})
    assoc_options
    options = BelongsToOptions.new(name, options)
    @assoc_options[name] = options

    define_method("#{name}") do
      return nil if self.send(options.foreign_key).nil?

      data = DBConnection.execute(<<-SQL)
        SELECT
          *
        FROM
          #{options.table_name}
        WHERE
          #{options.primary_key} = #{self.send(options.foreign_key)}
      SQL

      options.model_class.new(data.first)
    end
  end

  def has_many(name, options = {})
    options = HasManyOptions.new(name, self.name, options)

    define_method("#{name}") do

      data = DBConnection.execute(<<-SQL)
        SELECT
          *
        FROM
          #{options.table_name}
        WHERE
          #{options.foreign_key} = #{self.send(options.primary_key)}
      SQL

      data.map { |obj| options.model_class.new(obj) }
    end
  end

  def assoc_options
    @assoc_options ||= {}
  end

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

class SQLObject
  extend Associatable
end
