class KSTable

	def KSTable.is_a_kstable?
		true
	end

	def KSTable.field(localName, remoteName=nil, conversion=nil)
		remoteName = localName unless remoteName

		conversionCall = conversion ? ".#{conversion}" : ''
		addField(localName, remoteName)
    
		class_eval <<-EOS
def #{localName}
	@row['#{remoteName}']#{conversionCall}
end

def #{localName}=(val)
	unless pending_deletion? or read_only?
	  	@rollback_buffer.push ['#{remoteName}', @row['#{remoteName}']]
	  	@rollback_hash['#{remoteName}'] ||= []
	  	@rollback_hash['#{remoteName}'].push @row['#{remoteName}']
		@row['#{remoteName}'] = val
		changed
	end
end
EOS
	end
  
  	# A table can have more than one primary field?
  	
	def KSTable.primary(field)
		if defined?(@primaries) && @primaries
			@primaries << field unless @primaries.include?(field)
		else
			@primaries = [field]
		end
	end
  
	def KSTable.to_one(name, local_field, foreign_table, foreign_field = nil)
		foreign_table = foreign_table.to_s if Symbol === foreign_table
		if foreign_table.class.to_s == 'String'
			if KSDatabase.partial_to_complete_map.has_key?(foreign_table)
				foreign_table = KSDatabase.const_get KSDatabase.partial_to_complete_map[foreign_table]
			else
				foreign_table = nil
			end
		end
		
		# Need to throw an exception if foregin_table is bad.
		
		addRelation(name.to_s, KSToOne.new(self, local_field.to_s, foreign_table, foreign_field.to_s))
		class_eval <<-EOS
def #{name}
	self.class.relations['#{name}'].get(self)
end

def #{name}=(val)
	self.class.relations['#{name}'].set(self, val)
end
EOS
	end

	def KSTable.belongs_to(name, foreign_table, local_field, foreign_field = nil)
		foreign_table = foreign_table.to_s if Symbol === foreign_table
		if foreign_table.class.to_s == 'String'
			if KSDatabase.partial_to_complete_map.has_key?(foreign_table)
				foreign_table = KSDatabase.const_get KSDatabase.partial_to_complete_map[foreign_table]
			else
				foreign_table = nil
			end
		end
		
		# Need to throw an exception if foregin_table is bad.
		
		addRelation(name.to_s, KSBelongsTo.new(self, foreign_table, local_field.to_s, foreign_field.to_s))
		class_eval <<-EOS
def #{name}
	self.class.relations['#{name}'].get(self)
end

def #{name}=(val)
	self.class.relations['#{name}'].set(self, val)
end
EOS
	end

	def KSTable.to_many(name, foreign_table, foreign_field, local_field = nil)
		foreign_table = foreign_table.to_s if Symbol === foreign_table
		if foreign_table.class.to_s == 'String'
			if KSDatabase.partial_to_complete_map.has_key?(foreign_table)
				foreign_table = KSDatabase.const_get KSDatabase.partial_to_complete_map[foreign_table]
			else
				foreign_table = nil
			end
		end
		
		# Need to throw an exception if foregin_table is bad.
		
		addRelation(name.to_s, KSToMany.new(self, foreign_table, foreign_field.to_s, local_field.to_s))
		class_eval <<-EOS
def #{name}
	self.class.relations['#{name}'].get(self)
end

def #{name}_count
	self.class.relations['#{name}'].count(self)
end
EOS
	end
  
	def KSTable.all_fields
		database.query do |dbh|
			dbh.columns(table_name).each do |descr|
				fieldName = descr['name']
				field(fieldName, fieldName, conversion(descr['type_name']))
				if descr['primary']
					primary fieldName
				end
			end
		end
	end
  
	def KSTable.primaries
		@primaries
	end
  
	def KSTable.table_name
		class_eval 'Name'
	end
  
	def KSTable.database
		class_eval 'Database'
	end
  
	def KSTable.fields
		@fields
	end
  
	def KSTable.relations
		@relations
	end

	private
  
	def KSTable.addField(name, field)
		if defined?(@fields) && @fields
			@fields[name] = field
		else
			@fields = {name => field}
		end
	end

	def KSTable.addRelation(name, relation)
		if defined?(@relations)
			@relations[name] = relation
		else
			@relations = {name => relation}
		end
	end
  
	def KSTable.conversion(type)
		case type
		when /int/
			:to_i
		when /float/, /double/
			:to_f
		else
			nil
		end
	end
  
	def KSTable.canonical(fieldName)
		newName = fieldName.mixcase
		newName[0,1] = newName[0,1].downcase
		newName
	end

end
