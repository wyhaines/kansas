require 'test/unit'
require 'kansas'

class TC_NewWithoutDBH < Test::Unit::TestCase

	def setup
		@params = Hash.new
		begin
			IO.foreach('tests.conf') do |line|
				if m = /^\s*(\w+)\s*=\s*(.*)$/.match(line)
					@params[m[1].downcase] = m[2]
				end
			end
		rescue Exception
			raise "There was an error opening tests.conf.  Please verify that it exists and is readable, and then run the tests again."
		end

		unless @params['vendor']
			raise "Database vendor not found; please specify the database vendor in tests.conf."
		end

		unless @params['host']
			raise "Database host not found; please specify the database host in tests.conf."
		end

		unless @params['name']
			raise "Database name not found; please specify the database name in tests.conf."
		end
	
		assert_nothing_raised("Premature failure while creating the database handle during setup.") do
			@dbh = DBI.connect("dbi:#{@params['vendor']}:#{@params['name']}:#{@params['host']}",@params['user'],@params['password'])
		end
	end

	def testNew
		assert_nothing_raised("Failed while creating new KSDatabase with already existing database handle.") do
			@ksdbh = KSDatabase.new("dbi:#{@params['vendor']}:#{@params['name']}:#{@params['host']}",@params['user'],@params['password'])
		end
	end

end
