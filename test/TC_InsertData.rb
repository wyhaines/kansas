require 'rubygems'
require 'test/unit'
require 'kansas'
require 'dbi'

class TC_InsertData < Test::Unit::TestCase

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
			IO.foreach('create_tables.sql',';') do |line|
				begin
					@dbh.do line
				rescue Exception => e
					puts "DBI Error: #{e}"
					puts "For SQL: #{line}"
					puts "Continuing with tests...."
				end
			end
		end
		
		assert_nothing_raised("Failed while mapping tables and setting up relationships.") do
			@ksdbh = KSDatabase.new(@dbh)

			# Define the tables.  The syntax is to give the local name and
			# the remote name in the table() method.  The remote name is the
			# name of the actual table.  The local name is what we will call
			# it in the code.  The actual name of the class created for the
			# table will be DBCLASS::LOCALNAME.
			# i.e. a local name of 'Butterfly', with a Kansas subclass of
			# GardenDB would yield GardenDB::Butterfly.
			
			# begin/rescue ensures classes are only defined once.
			
			@ksdbh.table(:Students,'Students')
			@ksdbh.table('Courses',:Courses)
			@ksdbh.table('CoursesTaken','Courses_Taken')
			
			KSDatabase::CoursesTaken.to_one('course', 'name', 'Courses')
			KSDatabase::CoursesTaken.to_one(:student, :student_number, KSDatabase::Students)
			KSDatabase::Students.to_many(:courses_taken, KSDatabase::CoursesTaken, "student_number")
			KSDatabase::Courses.to_many(:students_taking, :CoursesTaken, :name)
		end
	end

	def showCourses

		# Iterate over each record in Courses.

		@ksdbh.select('Courses').each do |course|
			puts "#{course.name} taken by:"

			# Recall that above we defined a to_many relationship
			# in Courses pointing toward CoursesTaken.  Here we
			# iterate through each record of that to_many relationship.

			course.students_taking.each do |c|
				puts "    #{c.student.first_name}(##{c.student.student_number})"
		 	end
		end
	end
	
	def testInserts1
		puts "\n#####\nTesting insert operation.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		@ksdbh.autocommit = false
		puts "\nJanelle is a new student.  She is taking LAW102 and CSC301."
		janelle = @ksdbh.newObject('Students')
		janelle.first_name = 'Janelle'
		janelle.last_name = 'Barber'
		janelle.state = 'Wyoming'
		# To give her classes, we need the student number.  The number, nowever,
		# is determined after her record is inserted.  So, we need to insert
		# her record then reload it.
		@ksdbh.commit
		# This is not database portable, but then either are autoincrement
		# fields.  Here we are saying that match student_number to the value
		# returned by the 'last_insert_id()' database function.
		janelle = @ksdbh.select('Students') {|s| s.student_number == s._last_insert_id()}.first.dup
		
		# Now setup Janelle's classes.
		janelle_law = @ksdbh.newObject('CoursesTaken')
		janelle_law.name = 'LAW102'
		janelle_law.student_number = janelle.student_number
		janelle_csc = @ksdbh.newObject('CoursesTaken')
		janelle_csc.name = 'CSC301'
		janelle_csc.student_number = janelle.student_number
		@ksdbh.commit
		
		puts "\n\nAltered Students and their Courses:\n"
		showCourses
		puts "#####"
	end

end
