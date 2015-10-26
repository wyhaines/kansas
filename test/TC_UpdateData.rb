require 'test/unit'
require 'kansas'
require 'dbi'

class TC_UpdateData < Test::Unit::TestCase

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
	
	def testUpdates1
		puts "\n#####\nTesting basic update operations.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		puts "\n\nClass XZY987 is changing to ASL101."
		# Retrieve an object for the row to be changed.
		@ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.each do |xzycourse|
			# Change an attribute in the object.  If AutoCommit it on, and
			# by default, it is, then this change will automatically be
			# committed back to the database.
			# If AutoCommit were turned off, a specific call to commit() would
			# be necessary to save the changes.  This will be tested in another
			# test.
			xzycourse.name = 'ASL101'
		end
		@ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
			course_taken.name = 'ASL101'
		end
		
		puts "Sandy changed her name to Jessica."
		@ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.each do |sandy|
			sandy.first_name = 'Jessica'
		end
		
		puts "And Pete, not wanting to be left out, switches from LAW101 to ASL101."
		pete = *@ksdbh.select('Students') {|s| (s.first_name == 'Pete')}
		@ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
			oldclass.name = 'ASL101'
		end
		
		puts "\n\nAltered Students and their Courses:\n"
		showCourses
		puts "#####"
	end

end
