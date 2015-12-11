module kansas
  class ToOne

    attr_reader :foreignTable, :foreignField, :localTable, :localField

    def initialize(*args)
      @localTable, @localField, @foreignTable, @foreignField = args
      @foreignField = @foreignTable.primaries.first unless @foreignField != ''
    end

    def get(parent)
      if @foreignField != @foreignTable.primaries.first
        sql = "SELECT * FROM #{@foreignTable.table_name} " +
            "WHERE #{@foreignField} = '#{parent.row[@localField]}'"
        parent.context.select(@foreignTable, sql).first
      else
        parent.context.get_object(@foreignTable, [parent.row[@localField]])
      end
    end

    def set(parent, child)
      parent.row[@localField] = child.row[@foreignField]
      parent.changed
    end

    def join
      "#{@localTable.table_name}.#{@localField} = #{@foreignTable.table_name}.#{@foreignField}"
    end

  end
end