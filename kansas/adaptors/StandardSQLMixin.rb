class Object
	def expr_body
		to_s
	end
end

class Array
	def expr_body
		collect {|e| e.expr_body}.join(',')
	end
end

class String
	def expr_body
		KSDatabase.sql_escape(self)
	end
end

class KSStandardSQLMixin
	def select_sql(context)
		distinct_fields = []
		fields = []
		context.select_table.fields.each_value do |f|
			if context.distinct[f]
				distinct_fields.push "distinct(#{@context.select}.#{f})"
			else
				fields.push "#{@context.select}.#{f}"
			end
		end
		
		fields = distinct_fields.concat(fields)
		
		selectedTables = context.tables.compact.flatten.uniq.join(',')
		joinConstraints = context.joins.compact.flatten.uniq.join(' AND ')
		#selected_rows = context.select.compact.flatten.uniq.collect {|t| "#{t}.*"}.join(',')
		
		if joinConstraints != ""
			joinConstraints << " AND "
		end
    
		#statement = "SELECT #{context.select}.* FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
		statement = "SELECT #{fields.join(',')} FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
		statement << ' ORDER BY ' << context.sort_fields.collect {|f| "#{f[0].respond_to?(:expr_body) ? f[0].expr_body : f[0].to_s} #{f[1]}"}.join(',') if context.sort_fields.length > 0
		statement << ' LIMIT ' << context.limits.join(',') if context.limits.length > 0
		
		statement
	end

	def count_sql(context)
		selectedTables = context.tables.compact.flatten.uniq.join(',')
		joinConstraints = context.joins.compact.flatten.uniq.join(' AND ')
		#selected_rows = context.select.compact.flatten.uniq.collect {|t| "#{t}.*"}.join(',')
		
		if joinConstraints != ""
			joinConstraints << " AND "
		end
    
		statement = "SELECT count(*) FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
		statement << ' ORDER BY ' << context.sort_fields.collect {|f| "#{f[0].respond_to?(:expr_body) ? f[0].expr_body : f[0].to_s} #{f[1]}"}.join(',') if context.sort_fields.length > 0
		statement << ' LIMIT ' << context.limits.join(',') if @context.limits.length > 0

		statement
	end

	def delete_sql(context)
		selectedTables = context.tables.compact.flatten.uniq.join(",")
		joinConstraints = context.joins.compact.flatten.uniq.join(" AND ")
		if joinConstraints != ""
			joinConstraints << " AND "
		end
    
		statement = "DELETE FROM #{selectedTables} WHERE #{joinConstraints} #{expr_body}"
		
		statement
	end

	def build_where(object)
		build_where_from_key(object, object.key)
	end
  
	def build_where_from_key(object, key, tableflag = false)
		table = tableflag ? object : object.class
		where = " WHERE "
		where_ary = []
		fields = table.primaries
    
		fields.each_index do |i|
			if !tableflag && object.rollback_hash[fields[i]]
				val = object.rollback_hash[fields[i]].last
			else
				val = key[i]
			end
			
			where_ary.push "#{fields[i]} = #{KSDatabase.sql_escape(val)}"
		end
		where + where_ary.join(' AND ')
	end
  
	def build_update(object)
		update = "UPDATE #{object.table_name} SET "
		object.row.each do |field, val|
			update << " #{field} = #{KSDatabase.sql_escape(val)},"
		end
		update.chop!		
	end
end
