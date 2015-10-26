class KSBelongsTo

	attr_reader :foreignTable, :foreignField, :localTable, :localField

	def initialize(*args)
		@localTable, @foreignTable, @localField, @foreignField = args
		@foreignField = @foreignTable.primaries.first unless @foreignField != ''
	end
	
	def get(parent)
		parent.context.get_object(@foreignTable, [parent.row[@localField]])
	end
		
	def set(parent, child)
		parent.row[@localField] = child.row[@foreignField]
		parent.changed
	end
	
	def join
		"#{@localTable.table_name}.#{@localField} = #{@foreignTable.table_name}.#{@foreignField}"
	end
	
end