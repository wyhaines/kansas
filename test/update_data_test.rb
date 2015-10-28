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
  
describe "update data" do

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

  it "updates data" do
    starting_attendees = all_students_in_courses
    
    @ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.each do |xzycourse|
      xzycourse.name = 'ASL101'
    end

    @ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
      course_taken.name = 'ASL101'
    end
    
    xzy_is_now_asl = all_students_in_courses
    ( starting_attendees - xzy_is_now_asl ).each do |triple|
      lambda do |course, first_name, student_number|
        # Should only be the removed course, XZY987
        course.must_equal "XZY987"
      end
    end
   
    ( xzy_is_now_asl - starting_attendees ).each do |triple|
      lambda do |course, first_name, student_number|
        # Should only be the added course, ASL101
        course.must_equal "ASL101"
      end
    end
   
    @ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.each do |sandy|
      sandy.first_name = 'Jessica'
    end

    sandy_is_now_jessica = all_students_in_courses

    ( xzy_is_now_asl - sandy_is_now_jessica ).each do |triple|
      lambda do |course, first_name, student_number|
        # Should be just Sandy's classes.
        first_name.must_equal "Sandy"
      end
    end

    ( sandy_is_now_jessica - xzy_is_now_asl ).each do |triple|
      lambda do |course, first_name, student_number|
        # Should be just Jessica's classes.
        first_name.must_equal "Jessica"
      end
    end

    pete = @ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first
    @ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
      oldclass.name = 'ASL101'
    end
    
    pete_is_now_in_asl = all_students_in_courses

    ( sandy_is_now_jessica - pete_is_now_in_asl ).each do |triple|
      lambda do |course, first_name, student_number|
        # Pete's old LAW class
        course.must_equal 'LAW101'
        first_name.must_equal 'Pete'
      end
    end

    ( pete_is_now_in_asl - sandy_is_now_jessica ).each do |triple|
      lambda do |course, first_name, student_number|
        # Pete's old LAW class
        course.must_equal 'ASL101'
        first_name.must_equal 'Pete'
      end
    end
    
  end

end
