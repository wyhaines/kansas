require 'rubygems'
require 'test/unit'
require 'kansas'
require 'dbi'

class TC_DeleteData < Test::Unit::TestCase

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
	
	def testDeletes1
		puts "\n#####\nTesting basic row delete operations.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		pete = @ksdbh.select(:Students) {|s| s.student_number == 102}.first.dup
		# Before we delete Pete, we need to delete his courses_taken.
		pete.courses_taken.each {|c| c.delete}
		# Now Pete goes.
		pete.delete
		
		puts "\n\nAltered Students and their Courses:\n"
		showCourses
		puts "#####"
	end

	def testDeletes2
		puts "\n#####\nTesting basic row delete operations within a transaction.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		pete = @ksdbh.select(:Students) {|s| s.student_number == 102}.first.dup
		@ksdbh.transaction do
			# Before we delete Pete, we need to delete his courses_taken.
			pete.courses_taken.each {|c| c.delete}
			# Now Pete goes.
			pete.delete
		end		
		
		puts "\n\nAltered Students and their Courses:\n"
		showCourses
		puts "#####"
	end
	
	def testDeletes3
		puts "\n#####\nTesting rollback of basic row delete operations.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		pete = @ksdbh.select(:Students) {|s| s.student_number == 102}.first.dup
		@ksdbh.transaction do
			# Before we delete Pete, we need to delete his courses_taken.
			pete.courses_taken.each {|c| c.delete}
			# Now Pete goes.
			pete.delete
			
			puts "Pete's object should be nil'd and changes shouldn't stick to it."
			puts "Pete's number: #{pete.student_number}"
			puts "setting it to 123..."
			pete.student_number = 123
			puts "Pete's new number: #{pete.student_number}"
			puts "Now rolling back..."
			@ksdbh.rollback
		end		
		puts "Pete has a number again: #{pete.student_number}"
		
		puts "\n\nAnd nothing was deleted:\n"
		showCourses
		puts "#####"
	end
	
	def testDeletes4
		puts "\n#####\nTesting select()-like delete interface.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		puts "Class XZY987 is being canceled."
		@ksdbh.delete(:Courses) {|c| c.name == 'XZY987'}
		@ksdbh.delete(:CoursesTaken) {|ct| ct.name == 'XZY987'}
		
		puts "Courses without XYZ987:"
		showCourses
		puts "#####"
	end
	
	def testDeletes5
		puts "\n#####\nTesting select()-like delete interface with transactions.\n"
		puts "\nCurrent Students and the Courses they are taking:\n"
		showCourses
		
		@ksdbh.transaction do
			puts "\nEntering transaction."
		
			puts "Adding Pete to class XZY987."
			pete = @ksdbh.select(:Students) {|s| s.first_name == 'Pete'}.first.dup
			pete_xzy = @ksdbh.new_object(:CoursesTaken)
			pete_xzy.student_number = pete.student_number
			pete_xzy.name = 'XZY987'
			
			puts "Class XZY987 is being canceled."
			@ksdbh.delete(:Courses) {|c| c.name == 'XZY987'}
			@ksdbh.delete(:CoursesTaken) {|ct| ct.name == 'XZY987'}
			puts "Someone changed their mind; rolling back.\n\n"
			@ksdbh.rollback
		end
		
		puts "The classes, unaltered."
		showCourses
		puts "#####"
	end
end
