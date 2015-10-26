require 'rubygems'
require 'test/unit'
require 'kansas'
require 'dbi'

class TC_Transactions < Test::Unit::TestCase

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
			@ksdbh.commit
			@ksdbh.set_autocommit(false)
			
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
	
	def testTransactions1
		puts "\n#####\nTesting basic commit.\n\n"
		
		print "Name of student #101:"
		@ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |dbs101|
			puts dbs101.first_name
		end
		puts "Student #101 is changing her name to 'Jessica'."
		
		# Note the dup() on the end, here.  Remember that underneath we are using
		# dbi, and dbi recycles rows.  If you are planning on doing more queries,
		# and you want a row object not to change underneath you, you have to
		# dup it and work with the dup.
		
		s101 = @ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.dup
		s101.first_name = 'Jessica'
		puts "The object for student #101 now says her name is: #{s101.first_name}."
		@ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |dbs101|
			puts "  but the database still says: #{dbs101.first_name}"
		end
		puts "Commiting #{s101.first_name}"
		@ksdbh.commit
		@ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |dbs101|
			puts "After the commit, the database says: #{dbs101.first_name}"
		end
	end
	
	def testTransactions2
		puts "\n#####\nTesting basic rollback.\n\n"

		s101 = @ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.dup
		print "Name of student #101:"
		puts s101.first_name
		
		puts "Student #101 is changing her name to 'Jessica'."
		
		# Note the dup() on the end, here.  Remember that underneath we are using
		# dbi, and dbi recycles rows.  If you are planning on doing more queries,
		# and you want a row object not to change underneath you, you have to
		# dup it and work with the dup.
		

		s101.first_name = 'Jessica'
		puts "The object for student #101 now says her name is: #{s101.first_name}."
		@ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |dbs101|
			puts "  but the database still says: #{dbs101.first_name}"
		end
		puts "No, she changed her mind."
		@ksdbh.rollback
		@ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |dbs101|
			puts "After the rollback, the database says: #{dbs101.first_name}\nand the object says: #{s101.first_name}"
		end
	end
	
	def testTransactions3
		puts "\n#####\nTesting an extended commit of updates.\n\n"
		
		showCourses
				
		puts "\n\nPerforming multiple course/student updates"
		# Retrieve an object for the row to be changed.
		@ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.each do |xzycourse|
			xzycourse.name = 'ASL101'
		end
		
		@ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
			course_taken.name = 'ASL101'
		end
		
		@ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.each do |sandy|
			sandy.first_name = 'Jessica'
		end
		
		pete = @ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first.dup
		@ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
			oldclass.name = 'ASL101'
		end
		
		@ksdbh.commit
		
		puts "\nAltered Students and their Courses:\n"
		showCourses
		puts "#####"
	end
	
	def testTransactions4
		puts "\n#####\nTesting an extended commit of updates with block syntax.\n\n"
		
		showCourses
		
		puts "\n\nPerforming multiple course/student updates"
		# Retrieve an object for the row to be changed.
		
		@ksdbh.transaction do |ksdbh|
			ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.each do |xzycourse|
				xzycourse.name = 'ASL101'
			end
		
			ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
				course_taken.name = 'ASL101'
			end
		
			ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.each do |sandy|
				sandy.first_name = 'Jessica'
			end
		
			pete = ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first.dup
			ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
				oldclass.name = 'ASL101'
			end
		end
		
		puts "\nAltered Students and their Courses:\n"
		showCourses
		puts "#####"
	end
	
	def testTransactions5
		puts "\n#####\nTesting extended updates with exception causing rollback in block syntax.\n\n"
		
		showCourses
		
		puts "\n\nPerforming multiple course/student updates"
		# Retrieve an object for the row to be changed.
		
		begin
			@ksdbh.transaction do |ksdbh|
				ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.each do |xzycourse|
					xzycourse.name = 'ASL101'
				end
		
				ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
					course_taken.name = 'ASL101'
				end
		
				ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.each do |sandy|
					sandy.first_name = 'Jessica'
				end
		
				pete = ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first.dup
				ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
					oldclass.name = 'ASL101'
				end
			
				raise Exception.new("This should roll it back")
			end
		rescue Exception => e
			puts "Caught exception: #{e}"
		end
		
		puts "\nStudents and their Courses (should be unaltered):\n"
		showCourses
		puts "#####"
	end
end
