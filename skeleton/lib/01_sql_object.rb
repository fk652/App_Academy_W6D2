require_relative 'db_connection'
require 'active_support/inflector'
# NB: the attr_accessor we wrote in phase 0 is NOT used in the rest
# of this project. It was only a warm up.

class SQLObject
  def self.columns
    @columns ||= DBConnection.execute2(<<-SQL)
      SELECT *
      FROM #{self.table_name}
    SQL
    .first.map(&:to_sym)
  end

  def self.finalize!
    self.columns.each do |col_name|
      # define a getter
      define_method(col_name) do 
        self.attributes[col_name]
      end

      #define a setter
      setter_name = "#{col_name}="
      define_method(setter_name) do |new_val|
        self.attributes[col_name] = new_val
      end
    end
  end

  def self.table_name=(table_name)
    @table_name = table_name
  end

  def self.table_name
    @table_name ||= self.inspect.tableize
    @table_name
  end

  def self.all
    query = DBConnection.execute(<<-SQL)
      SELECT *
      FROM #{self.table_name}
    SQL
    self.parse_all(query)
  end

  def self.parse_all(results)
    results.map do |params|
      self.new(params)
    end
  end

  def self.find(id)
    query = DBConnection.execute(<<-SQL, id)
      SELECT *
      FROM #{self.table_name}
      WHERE id = ?
    SQL
    self.parse_all(query).first
  end

  def initialize(params = {})
    params.each do |attr_name, value|
      attr_sym = attr_name.to_sym

      raise "unknown attribute '#{attr_name}'" unless self.class.columns.include?(attr_sym)

      self.send("#{attr_sym}=", value)
    end
  end

  def attributes
    @attributes ||= {}
  end

  def attribute_values
    self.attributes.values
  end

  def insert
    insert_columns = self.class.columns.drop(1)
    col_names = insert_columns.join(', ')
    question_marks = Array.new(insert_columns.length, '?').join(', ')

    DBConnection.execute(<<-SQL, *self.attribute_values)
      INSERT INTO 
        #{self.class.table_name} (#{col_names})
      VALUES 
        (#{question_marks})
    SQL

    new_id = DBConnection.last_insert_row_id
    self.id = new_id
  end

  def update
    insert_columns = self.class.columns.drop(1)
    set_cols = insert_columns.map{|attr_name| "#{attr_name} = ?"}.join(', ')

    DBConnection.execute(<<-SQL, *self.attribute_values.drop(1), self.id)
      UPDATE
        #{self.class.table_name} 
      SET
        #{set_cols}
      WHERE
        id = ?
    SQL
  end

  def save
    self.id.nil? ? self.insert : self.update
  end
end
