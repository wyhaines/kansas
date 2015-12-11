require 'forwardable'

#####
# Note: If you are reading the code, be aware that a lot of this is going to 
#  be changing.  Better exception handling (really, any exception handling
#  will be better exception handling), better code organization, more comments,
#  and more consistency in the use of snake_case.
#  If you want to spend a little time helping out, I welcome patches.
#  wyhaines@gmail.com
#####

#####
# Note: One fairly highly ranked item on the todo list is to add capability
#   to join on fields other than primary key fields.  I also want to be able
#   to define views -- objects that present a joined view of part or all
#   of two or more tables.  Along with this will probably come the ability,
#   when mapping a table, to specify specific columns to map or not to
#   map.
#####

# Escapes quotes inside of a SQL statement.
# ToDo:  Make this obsolete by having all SQL statements use bind variables.

def sql_escape(val)
	"'" + val.to_s.gsub("'", "\\\\'") + "'"
end

# TODO: Let's not have egregious monkey patches, mkay?
class String

	# Converts a string so that each initial letter after an underscore is
	# an uppercase letter.
	
	def mixcase
		if self == upcase
			res = downcase
		else
			res = dup
		end
   		res.gsub(/_(\w)/) {$1.upcase}
	end
	
end

module Kansas
  class BadTable < Exception;end
  class NoTable < Exception;end
  class BadFieldName < Exception;end
  class Rollback < Exception;end
  class Null < NilClass;end
end

require 'drb'

class Database

	include DRbUndumped

	extend Forwardable
	def_delegators('@dbh','connected?','disconnect','do','ping','prepare','execute','select_all','select_one','quote','tables','columns')
	
	@@partial_to_complete_map = {}
	
	def Database.partial_to_complete_map
		@@partial_to_complete_map
	end
	
	attr_reader :options, :tables
	attr_accessor :dbh
	
	# Initialize Kansas.  Kansas optionally accepts a database handle.  This
	# allows an external system, such as a database connection pool, to be
	# used with Kansas.
	
	def initialize(arg1 = nil, arg2 = nil, arg3 = nil, arg4 = nil)
		# If a database handle is passed in as the first arg, then the second should be an options has.
		# If the first arg is a string, then it is assumed to be a dsn and the next two args will be
		# username and password, followed by options.
		if String === arg1
			dsn = arg1
			username = arg2
			password = arg3
			options = arg4 ? arg4 : {}
		else
			dbh = arg1
			options = arg2 ? arg2 : {}
		end
		
		if dbh
			@dbh = dbh
			@options = options
		elsif dsn
			connect_using(dsn,username,password,options)
			new_dbh
		else
			@options = options
		end

		@objects = {}
		@changed = []    
  		@remote_to_local_map = {}
		set_autocommit
	end
	
	# Set the parameters used for making a DBI connection.
	
 	def connect_using(dsn, user, password, options = {})
		@dsn = dsn
		@user = user
		@password = password
		@options = options
	end
	alias :connectUsing :connect_using
	
	def new_dbh
		@dbh = DBI.connect(@dsn, @user, @password) if @dsn
	end
	alias :newDbh :new_dbh

	def query(*args,&blk)
		error_recovery ||= false
		yield(@dbh,*args)
	rescue Exception => e
		unless error_recovery
			error_recovery = true
			new_dbh
			retry
		else
			raise e
		end
	end

 	def autocommit?
 		@options[:autocommit]
 	end
  	
  	def autocommit
  		autocommit?
  	end
  	
  	def autocommit=(setting)
  		set_autocommit setting
  	end
  	
  	def set_autocommit(setting = nil)
  		if setting != nil
  			@options[:autocommit] = setting ? true : false
  		else
  			@options[:autocommit] = true
  		end
  	end
  	alias :setAutocommit :set_autocommit
  	
	def has_object?(table, key)
		if tableHash = @objects[table]
			tableHash[key]			
		else
			@objects[table] = {}
			nil
		end
 	end

	def get_object(table, key)
		unless obj = has_object?(table,key)
			if obj = load_object(table,key,true)
				obj.set_serialized
				register_object(obj)
			end
		end
		obj
	end
 
 	# Updates the record in the database for the object.
 	
	def store_object(object)
		#sql = build_update(object) + build_where(object)
		#query {|dbh| dbh.do(sql)}
		rs = build_update(object)
		sql = rs.first + build_where(object)
		query {|dbh| dbh.do(sql,*rs.last)}
	end

	def get_table_from_string(table)
		if Database.partial_to_complete_map.has_key?(table)
			table = self.class.const_get Database.partial_to_complete_map[table]
		elsif @remote_to_local_map.has_key?(table)
			table = self.class.const_get @remote_to_local_map[table]
		else
			nil
		end
	end

	def check_query_args(*args)
		tables = []
		read_only = false
		final_value = args.length > 1 ? args.last : nil
		sql = ''
		
		args.each do |table|
			if table == :__read_only__
				read_only = true
				next
			end
			
			final_flag = (table == final_value)
			table = table.to_s if table.kind_of?(Symbol)
			if table.kind_of?(String)
				tclass = get_table_from_string(table)
				if tclass
					table = tclass
				else
					if final_flag
						sql << table
					else
						self.map_all_tables
						table = get_table_from_string(table)
					end
				end
			end
			tables << table if table
		end
		
		unless sql != ''
			if tables.length == 0
				raise NoTable, "NoTable: No valid tables were found to operate against."
			else
				tables.each do |t|
					unless t.respond_to?(:is_a_kstable?)
						raise BadTable.new,"BadTable: #{t} is not a valid table."
					end
				end
			end
		end	

		[tables,sql,read_only]
	end

	
	# Selects from a table.  If a block is given, that block will be used
	# to construct the SQL statement.  Otherwise, if a SQL statement was
	# given as the second argument, that statement will be used.  If no
	# statement was given, the default is to select * from the table provided
	# as the first argument.  The table can either be specified by passing
	# the class for the table to use (e.x. Kansas::Database::Students), by passing
	# the remote name (i.e. the name of the actual database table), or by
	# passing the local name for the table that was given when mapping the
	# table. Most of the time the local name or the remote name should be
	# used as it works just as well as the full class name.
	#
	# Note that select'd currently operates outside of the local rollback cache.
	def select(*args)
		error_recovery ||= false
		results = []
		tables,sql,read_only = check_query_args(*args)

		if block_given?
			context = Expression::Context.new(*tables)
			yield_args = tables.collect {|t| TableExpr.new(t,context)}
			queryExpr = yield *yield_args
			sql = queryExpr.select_sql
		elsif sql == ''
			sql = "SELECT * FROM #{tables.collect {|t| t.table_name}.join(',')}"
		end
		
		Kansas::log("select: '#{sql}'") if $DEBUG

		rawResults = query do |dbh|
			dbh.select_all(sql) do |row|
				results << add_object(tables[0].new.load(row.to_h, self, read_only))
			end
		end

		results
	rescue DBI::DatabaseError => e
		unless error_recovery
			error_recovery = true
			new_dbh
			retry
		else
			raise e
		end
	end
	
	# Return only one value from a query.
	
	def select_first(*args,&blk)
		select(*args) {|*yargs| blk.call(*yargs)}.first
	end
	
	# Returns only a count of the records selected by the query.
	def count(*args)
		error_recovery ||= false
		results = nil
		tables,sql = check_query_args(*args)

		if block_given?
			context = Expression::Context.new(*tables)
			yield_args = tables.collect {|t| TableExpr.new(t,context)}
			queryExpr = yield *yield_args
			sql = queryExpr.count_sql
		elsif sql == ''
			sql = "SELECT count(*) FROM #{tables.collect {|t| t.table_name}.join(',')}"
		end
		
		Kansas::log("select: '#{sql}'") if $DEBUG

		rawResults = query do |dbh|
			dbh.select_all(sql) do |row|
				results = row[0]
			end
		end

		results
	rescue DBI::DatabaseError => e
		unless error_recovery
			error_recovery = true
			new_dbh
			retry
		else
			raise e
		end
	end
	
	# A convenience usage of count().  Returns true if the query would return
	# any number of rows, or false if the query would not return any rows.
	
	def exists?(*args,&block)
		if block
			0 < count(*args) {|*blockargs| block.call(*blockargs)}
		else
			0 < count(*args)
		end
	end
	# Delete removes one or more rows from the database.  It _also_ returns
	# an array of objects matching the rows deleted.  If Autocommit is not on,
	# it will return the array of rows that would be deleted _at the time of
	# the call_ and will defer the actual deletion from the database until a
	# commit() is invoked.
	
	def delete(table, sql=nil)
		error_recovery ||= false
		table = table.to_s if table.kind_of?(Symbol)
		
		if table.kind_of?(String)
			if @remote_to_local_map.has_key?(table)
				table = self.class.const_get @remote_to_local_map[table]
			elsif Database.partial_to_complete_map.has_key?(table)
				table = self.class.const_get Database.partial_to_complete_map[table]
			else
				table = nil
			end
		end

		unless Class === table
			raise BadTable,"BadTable: #{table} is not a valid table."
		end

		if block_given?
			queryExpr = yield TableExpr.new(table)
			select_sql = queryExpr.sql
			delete_sql = queryExpr.delete_sql
		elsif sql == nil
			select_sql = "SELECT * FROM #{table.table_name}"
			delete_sql = "DELETE FROM #{table.table_name}"
		end

		Kansas::log("delete: '#{sql}'") if $DEBUG

		results = []
		rawResults = query do |dbh|
			dbh.select_all(select_sql) do |row|
				results.push add_object(table.new.load(row.to_h, self))
			end
		end
		
		if autocommit?
			query {|dbh| dbh.do delete_sql}
		else
			changed delete_sql
		end
		
		results
	rescue DBI::DatabaseError => e
		unless error_recovery
			error_recovery = true
			new_dbh
			retry
		else
			raise e
		end
	end
	
	def delete_one(object)
		sql = "DELETE FROM #{object.table_name} #{build_where(object)}"
		result = query {|dbh| dbh.do sql}
		unregister_object object
		result
	end
		
	# Use decoupled_object() to create an object that is not yet connected to
	# a database.

	def decoupled_object(table, rowdata = {})
		table = table.to_s if table.is_a? Symbol
		if table.kind_of? String
			if @remote_to_local_map.has_key?(table)
				table = self.class.const_get @remote_to_local_map[table]
			elsif Database.partial_to_complete_map.has_key?(table)
				table = self.class.const_get Database.partial_to_complete_map[table]
			else
				table = nil
			end
		end
		
                rowdata.each do |k,v|
                        if k.is_a?(Symbol)
                                rowdata.delete(k)
                                rowdata[k.to_s] = v
                        end
                end
		table.new.load(rowdata)
	end

	# Use new_object() to create new records within a table.
	
	def new_object(table,rowdata = {})
		object = decoupled_object(table,rowdata)
		register_object object
		object.context = self
		if autocommit?
			insert_object object
			object.set_serialized
		else
			changed object
		end
		
		object
	end
	alias :newObject :new_object
	
	# Take a table object that is not tied to the database and tie it.

	def register_and_insert_object(object)
		register_object object
		object.context = self
		insert_object object
		object.set_serialized
		object
	end
  	# Block oriented interface to commit/rollback.
  	  	
  	def transaction
  		old_autocommit = autocommit?
  		old_dbh_autocommit = @dbh['AutoCommit']
  		set_autocommit false
  		@dbh['AutoCommit'] = false
  		@transaction_flag = true
  		begin
  			commit
  			yield self
   			commit
  		rescue Rollback
  			# We caught a Rollback; this isn't really an error.
  			@transaction_flag = false
  			rollback
  		rescue Exception
 			# Something bad happened.
 			@transaction_flag = false
 			rollback
 			raise
  		end
  		set_autocommit(old_autocommit)
  		@dbh['AutoCommit'] = old_dbh_autocommit
  	end
  
	# Commit transaction to the database.
	
	def commit
		query do |dbh|
			dbh.transaction do
				@changed.uniq.each do |o|
					if o.kind_of?(String)
						query {|innerdbh| innerdbh.do o.to_s}
					elsif o.pending_deletion?
						delete_one o
					elsif o.serialized?
						store_object o
					else
						insert_object o
					end
					o.rollback_buffer = []
				end
				@changed.clear
			end
			dbh.commit
		end
	end

	# Rollback uncommitted transactions on an object so that they never get
	# to the database.
	
	def rollback
		if @transaction_flag
			raise Rollback
		else
			@changed.uniq.each do |o|
				next if o.kind_of?(String)
				o.rollback
			end
			@changed.clear
		end
		query {|dbh| dbh.rollback}
	end

	def changed(obj)
		@changed << obj
		if autocommit?
			commit
		end
	end
	
	def all_tables
		query do |dbh|
			dbh.tables.each do |table_name|
				Kansas.log("Defining table: #{table_name} as #{canonical(table_name)}") if $DEBUG
				table(canonical(table_name), table_name)
			end
		end
	end
	alias :map_all_tables :all_tables

	def table(local_name, remote_name=nil)
		local_name = local_name.to_s
		remote_name = local_name unless remote_name
		remote_name = remote_name.to_s
		
		old_local_name = local_name
		local_name  = make_constant_name(local_name)
		table = Class.new(Table)
		table.const_set('Name', remote_name)
		table.const_set('Database', self)
		table.all_fields
		
		@remote_to_local_map[remote_name] = local_name
		Database.partial_to_complete_map[old_local_name] = local_name
		addTable(local_name, table)
	end
	alias :map_table :table

	private

	def addTable(name, table)
		self.class.const_set(name, table) unless self.class.const_defined?(name)
		if defined?(@tables) && @tables
			@tables[name] = table
		else
			@tables = {name => table}
		end
	end

	def canonical(table_name)
		newName = table_name.mixcase
		make_constant_name(newName)
	end

	def make_constant_name(name)
		name = name.dup
		name[0,1] = name[0,1].upcase
		name
	end
	
  	# Inserts a new record in the database for the object.
  	# Because auto increment fields and timestamp fields on MySQL, and
  	# presumably other field types on other dbs, require that no explicit
  	# overriding value be inserted into the field, any field that has a nil
  	# value is omitted from the insert statement.  To explicity place a
  	# null value in a field when inserting into the database, use
  	# Null as the value of the field.
	
	def insert_object(object)
		unless object.serialized?
			table = object.class
			fields = table.fields.values.collect {|f| object.row[f] != nil ? f : nil}.compact
			sql = "INSERT into #{table.table_name} (#{fields.join(',')}) VALUES ("
			sql << fields.collect {|f| '?'}.join(',') << ')'
			query {|dbh| dbh.do(sql,*fields.collect {|f| object.row[f] == Null ? nil : object.row[f]})}
		end
	end
	
	def add_object(object)
		if cachedObj = has_object?(object.class, object.key)
			cachedObj.row = object.row
			cachedObj
		else
			object.set_serialized
			register_object(object)
		end
	end

	def register_object(object)
		key = object.key
		has_object?(object.class,key)
		@objects[object.class][key] = object
	end

	def unregister_object(object)
		key = object.key
		@objects[object.class].delete key
	end
	
	def load_object(object, key, tableflag = false)
		table = tableflag ? object : object.class
		query = "SELECT * FROM #{table.table_name}" + build_where_from_key(object, key, tableflag)
		row = nil
		row = query {|dbh| dbh.select_one(query)}
		if row
			table.new.load(row.to_h, self)
		else
			nil
		end
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
			
			where_ary.push "#{fields[i]} = #{sql_escape(val)}"
		end
		where + where_ary.join(' AND ')
	end
  
	def build_update(object)
		vals = []
		update = "UPDATE #{object.table_name} SET "
		object.row.each do |field, val|
			#update << " #{field} = #{sql_escape(val)},"
			update << " #{field} = ?,"
			vals << val
		end
		[update.chop!,vals]
		#update.chop!		
	end

	def build_select(table, criteria)
		criteriaString = "WHERE #{criteria}" if criteria
		"SELECT * FROM #{table.table_name} #{criteriaString}"
	end

end
