module Kansas
  class ToMany

    def initialize(*args)
      @localTable, @foreignTable, @foreignField, @localField = args
      @localField = @localTable.primaries.first unless @localField != ''
    end

    def get(parent)
      sql = "SELECT * FROM #{@foreignTable.table_name} " +
          "WHERE #{@foreignField} = '#{parent.row[@localField]}'"
      parent.context.select(@foreignTable, sql)
    end
  end
end