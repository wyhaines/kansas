class KSTable
	include DRbUndumped


	attr_accessor :row, :context, :rollback_buffer, :rollback_hash

	def pending_deletion?
		@deletion
	end

	def read_only?
		@read_only
	end
	alias :read_only :read_only?
	
	def read_only=(cond)
		@read_only = cond ? true : false
	end
	
	def serialized?
		@serialized
	end

	def set_pending_deletion
		@deletion = true
	end
	
	def reset_pending_deletion
		@deletion = false
	end
	
	def set_serialized
		@serialized = true
	end
	
	def initialize
		@row = {}
		@rollback_buffer = []
		@rollback_hash = {}
		@serialized = false
		@pending_deletion = false
		@read_only = false
	end
  
	def load(row, context = nil, read_only = false)
		@row, @context, @read_only = row, context, read_only
		self
	end
  
	def key
		result = self.class.primaries.collect{|f| @row[f.to_s]}
	end
  
	def changed
		@context.changed(self) if defined?(@context) && @context
	end
  
	def table_name
		self.class.table_name
	end

	def inspect
		table_name + @row.inspect
	end

	def delete # TODO: Add a cascade_delete that deletes the row plus any to_many relations to the row.
		if @context.autocommit?
			@context.delete_one(self)
		else
			set_pending_deletion
			changed
			nullify_self
		end
	end
	
	def nullify_self
		@rollback_buffer.push self.dup
		@row.each_key do |key|
			@rollback_hash[key] ||= []
			@rollback_hash[key].push @row[key]
		end
		
		@row = {}
	end
	# Unwind the changes.
	
	def rollback
		@rollback_buffer.reverse.each do |rbval|
			if rbval.class == Array
				@row[rbval[0]] = rbval[1]
			else
				@row = rbval.row
				reset_pending_deletion
			end
		end
		@rollback_buffer.clear
		@rollback_hash.each_key do |key|
			@rollback_hash[key].clear
		end
	end
	
end
