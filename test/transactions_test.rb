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
  
describe "transactions" do
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
    @ksdbh.commit
    @ksdbh.set_autocommit(false)
      
    @ksdbh.table(:Students,'Students')
    @ksdbh.table('Courses',:Courses)
    @ksdbh.table('CoursesTaken','Courses_Taken')
      
    KSDatabase::CoursesTaken.to_one('course', 'name', 'Courses')
    KSDatabase::CoursesTaken.to_one(:student, :student_number, KSDatabase::Students)
    KSDatabase::Students.to_many(:courses_taken, KSDatabase::CoursesTaken, "student_number")
    KSDatabase::Courses.to_many(:students_taking, :CoursesTaken, :name)
  end

  it "basic commit" do
    sandy = @ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.dup
    sandy.first_name.must_equal "Sandy"

    sandy.first_name = 'Jessica'
    sandy.first_name.must_equal 'Jessica'

    @ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |should_still_be_sandy|
      should_still_be_sandy.first_name.must_equal "Sandy"
    end

    @ksdbh.commit

    @ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |now_it_should_be_jessica|
      now_it_should_be_jessica.first_name.must_equal "Jessica"
    end
  end
  
  it "basic rollback" do

    sandy = @ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.dup
    sandy.first_name.must_equal "Sandy"
    
    sandy.first_name = 'Jessica'
    sandy.first_name.must_equal 'Jessica'

    @ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |should_still_be_sandy|
      should_still_be_sandy.first_name.must_equal "Sandy"
    end

    @ksdbh.rollback

    @ksdbh.select('Students') {|s| (s.student_number == 101)}.each do |should_still_be_sandy|
      should_still_be_sandy.first_name.must_equal "Sandy"
    end
  end
  
  it "extended commit" do
    
    starting_attendees = all_students_in_courses
        
    @ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.first.name = 'ASL101'
    @ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
      course_taken.name = 'ASL101'
    end
    
    @ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.first_name = 'Jessica'
    
    pete = @ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first.dup
    @ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
      oldclass.name = 'ASL101'
    end
    
    @ksdbh.commit
    
    changed_courses_and_students = all_students_in_courses

  end
  
  it "extended updates in a transaction block" do
    starting_attendees = all_students_in_courses
    
    @ksdbh.transaction do |ksdbh|
      ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.first.name = 'ASL101'
      ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
        course_taken.name = 'ASL101'
      end
    
      ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.first_name = 'Jessica'
    
      pete = ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first.dup
      ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
        oldclass.name = 'ASL101'
      end
    end
    
  end
  
  it "extended updates in a transaction block, with an exception triggering rollback" do
    starting_attendees = all_students_in_courses
    
    begin
      @ksdbh.transaction do |ksdbh|
        ksdbh.select('Courses') {|c| (c.name == 'XZY987')}.first.name = 'ASL101'
        ksdbh.select('CoursesTaken') {|c| (c.name == 'XZY987')}.each do |course_taken|
          course_taken.name = 'ASL101'
        end
    
        ksdbh.select('Students') {|s| (s.first_name == 'Sandy')}.first.first_name = 'Jessica'
    
        pete = ksdbh.select('Students') {|s| (s.first_name == 'Pete')}.first.dup
        ksdbh.select('CoursesTaken') {|ct| (ct.name == 'LAW101') & (ct.student_number == pete.student_number)}.each do |oldclass|
          oldclass.name = 'ASL101'
        end

        raise Exception.new("This should roll it back")
      end

    rescue Exception => e
      e.to_s.must_equal "This should roll it back"
    end
    
  end
end
