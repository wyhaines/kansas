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
  
describe "select data" do
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

    @ksdbh.table('Students','Students')
    @ksdbh.table('Courses','Courses')
    @ksdbh.table('CoursesTaken','Courses_Taken')
      
    KSDatabase::CoursesTaken.to_one(:course, "name", KSDatabase::Courses)
    KSDatabase::CoursesTaken.to_one(:student, "student_number", KSDatabase::Students)
    KSDatabase::Students.to_many(:courses_taken, KSDatabase::CoursesTaken, "student_number")
    KSDatabase::Courses.to_many(:students_taking, KSDatabase::CoursesTaken, "name")
  end

  it "basic select works" do
    all = all_students_in_courses
    all.length.must_equal 17
    all.each do |triple|
      lambda do |course, first_name, student_number|
        ['Dave', 'Sandy', 'Pete', 'Pippa', 'Wilma', 'Charlie'].must_include first_name
        ['CSC301', 'LAW101', 'LAW102', 'PHL312', 'XZY987'].must_include course
        (100..105).must_include student_number
      end.call(*triple)
    end
  end
  
  it "basic where specification works" do
    @ksdbh.select('Students') {|s| (s.student_number < 102) | (s.student_number > 104)}.each do |student|
      [102, 103, 104].include?(student.student_number).wont_equal true
    end
  end
  
  it "selection with an order by works" do
    num = 10000
    @ksdbh.select('Students') do |s|
      s.sort_by(s.student_number => 'desc') #Modifiers to the select must be specified first.
      (s.student_number.in(101,102,103))
    end.each do |student|
      [101, 102, 103].include?(student.student_number).must_equal true
      student.student_number.must_be :<,num
      num = student.student_number
    end
  
    num = 0
    @ksdbh.select('Students') do |s|
      s.sort_by(s.student_number => 'asc') #Modifiers to the select must be specified first.
      (s.student_number.between(103,106))
    end.each do |student|
      [103, 104, 105, 106].include?(student.student_number).must_equal true
      student.student_number.must_be :>,num
      num = student.student_number
    end

    num = 0
    @ksdbh.select('Students') do |s|
      s.sort_by(s.student_number => 'asc') #Modifiers to the select must be specified first.
      (s.student_number.not_between(102,104))
    end.each do |student|
      [102, 103, 104].include?(student.student_number).wont_equal true
      student.student_number.must_be :>,num
      num = student.student_number
    end
  end
  
  it "select with a limit clause works" do
    num = 0
    students = @ksdbh.select('Students') do |s|
      s.sort_by(s.student_number => 'asc')
      s.limit 2
    end

    students.length.must_equal 2
    students.each do |student|
      student.student_number.must_be :>,num
      num = student.student_number
    end
  end

  it "select with &, and != works" do
    students = @ksdbh.select('Students') do |s|
      s.student_number != 101
    end.each do |student|
      [100, 102, 103, 104, 105, 106].include?(student.student_number).must_equal true
    end

    students = @ksdbh.select('Students') do |s|
      ( s.student_number != 101 ) & ( s.first_name != 'Pete' )
    end.each do |student|
      [100, 102, 103, 104, 105, 106].include?(student.student_number).must_equal true
    end
  end
end
