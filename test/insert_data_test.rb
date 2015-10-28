require 'test_helper'
require 'rubygems'
require 'kansas'
require 'dbi'

def all_students_in_courses
  result = []
  @ksdbh.select('Courses').each do |course|
    course.students_taking.each do |c|
      result << [course.name, c.student.first_name, c.student.student_number ]
    end
  end

  result
end
  
describe "Data insertion" do
  before do
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
  
    @dbh = DBI.connect("dbi:#{@params['vendor']}:#{@params['name']}:#{@params['host']}",@params['user'],@params['password'])
    IO.foreach(File.join(File.dirname(__FILE__),'create_tables.sql'),';') do |line|
      begin
        @dbh.do line
      rescue Exception => e
        puts "DBI Error: #{e}"
        puts "For SQL: #{line}"
        puts "Continuing with tests...."
      end
    end
    
    @ksdbh = KSDatabase.new(@dbh)

    @ksdbh.table(:Students,'Students')
    @ksdbh.table('Courses',:Courses)
    @ksdbh.table('CoursesTaken','Courses_Taken')
      
    KSDatabase::CoursesTaken.to_one('course', 'name', 'Courses')
    KSDatabase::CoursesTaken.to_one(:student, :student_number, KSDatabase::Students)
    KSDatabase::Students.to_many(:courses_taken, KSDatabase::CoursesTaken, "student_number")
    KSDatabase::Courses.to_many(:students_taking, :CoursesTaken, :name)
  end

  it "basic insertion" do
    starting_attendees = all_students_in_courses
    
    @ksdbh.autocommit = false
    janelle = @ksdbh.newObject('Students')
    janelle.first_name = 'Janelle'
    janelle.last_name = 'Barber'
    janelle.state = 'Wyoming'
    @ksdbh.commit
    janelle = @ksdbh.select('Students') {|s| s.student_number == s._last_insert_id()}.first.dup
    
    janelle_law = @ksdbh.newObject('CoursesTaken')
    janelle_law.name = 'LAW102'
    janelle_law.student_number = janelle.student_number
    janelle_csc = @ksdbh.newObject('CoursesTaken')
    janelle_csc.name = 'CSC301'
    janelle_csc.student_number = janelle.student_number
    @ksdbh.commit
    
    janelle_classes = ( all_students_in_courses - starting_attendees ).each do |triple|
      lambda do |course, first_name, student_number|
        ['CSC301','LAW102'].must_include course
        first_name.must_equal 'Janelle'
        student_number.must_equal janelle.student_number
      end.call(*triple)
    end
  end

end
