require 'rubygems'
require 'test/unit'
require 'kansas'
require 'dbi'

class TC_SelectData < Test::Unit::TestCase

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
begin
			@ksdbh = KSDatabase.new(@dbh)

			# Define the tables.  The syntax is to give the local name and
			# the remote name in the table() method.  The remote name is the
			# name of the actual table.  The local name is what we will call
			# it in the code.  The actual name of the class created for the
			# table will be DBCLASS::LOCALNAME.
			# i.e. a local name of 'Butterfly', with a Kansas subclass of
			# GardenDB would yield GardenDB::Butterfly.
			
			# begin/rescue ensures classes are only defined once.
			
			@ksdbh.table('Students','Students')
			@ksdbh.table('Courses','Courses')
			@ksdbh.table('CoursesTaken','Courses_Taken')
			
			KSDatabase::CoursesTaken.module_eval <<ECODE
			    to_one(:course, "name", KSDatabase::Courses)
			    to_one(:student, "student_number", KSDatabase::Students)
ECODE
			
			KSDatabase::Students.module_eval <<ECODE
				to_many(:courses_taken, KSDatabase::CoursesTaken, "student_number")
ECODE
			
			KSDatabase::Courses.module_eval <<ECODE
				to_many(:students_taking, KSDatabase::CoursesTaken, "name")
ECODE
rescue Exception => e
puts e
puts e.backtrace.join("\n")
raise e
end
		end
	end

	def testSelects1
		puts "Courses and the Sudents taking them:\n"

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
	
	def testSelects2
		puts "\nStudents and the Courses they are taking:\n"

		# Iterate over each Student.

		@ksdbh.select(KSDatabase::Students).each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			
			# Traverse the to_many relationship of Student to
			# CoursesTaken to get the courses for each Student.
			
			student.courses_taken.each do |c|
    			puts "    #{c.course.name}"
    		end
    	end
	end
	
	def testSelects3
		puts "\nOnly Students with numbers < 102 or > 104, and their Courses:\n"

		# select() can take a block.  This block uses Ruby statements to define
		# the boolean statements of the WHERE clause in the underlying SQL
		# query that is generated.
		
		@ksdbh.select('Students') {|s| (s.student_number < 102) | (s.student_number > 104)}.each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			student.courses_taken.each do |c|
				puts "    #{c.course.name}"
			end
		end
	end
	
	def testSelects4
		puts "\nOnly Students with numbers in (101, 102, 103), in descending order, and their Courses:\n"
		
		@ksdbh.select('Students') do |s|
			s.sort_by(s.student_number => 'desc') #Modifiers to the select must be specified first.
			(s.student_number.in(101,102,103))
		end.each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			student.courses_taken.each do |c|
				puts "    #{c.course.name}"
			end
		end
	end
	
	def testSelects5
		puts "\nOnly Students with numbers between 103 and 106, in ascending order, and their Courses:\n"
		
		@ksdbh.select('Students') do |s|
			s.sort_by(s.student_number => 'asc') #Modifiers to the select must be specified first.
			(s.student_number.between(103,106))
		end.each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			student.courses_taken.each do |c|
				puts "    #{c.course.name}"
			end
		end
	end

	def testSelects6
		puts "\nOnly Students with numbers not between 102 and 104, in ascending order, and their Courses:\n"
		
		@ksdbh.select('Students') do |s|
			s.sort_by(s.student_number => 'asc') #Modifiers to the select must be specified first.
			(s.student_number.not_between(102,104))
		end.each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			student.courses_taken.each do |c|
				puts "    #{c.course.name}"
			end
		end
	end
	
	def testSelects7
		puts "\nOnly Students with numbers not between 102 and 104, in ascending order, and their Courses:\n"
		
		@ksdbh.select('Students') do |s|
			s.sort_by(s.student_number => 'asc') #Modifiers to the select must be specified first.
			(s.student_number.not_between(102,104))
		end.each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			student.courses_taken.each do |c|
				puts "    #{c.course.name}"
			end
		end
	end

	def testSelects8
		puts "\nThe student with the lowest two student_number values and their Courses:\n"
		
		@ksdbh.select('Students') do |s|
			s.sort_by(s.student_number => 'asc')
			s.limit 2
		end.each do |student|
			puts "#{student.first_name}(##{student.student_number}) takes:"
			student.courses_taken.each do |c|
				puts "    #{c.course.name}"
			end
		end
	end

end
