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
  
describe "Data deletion" do
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

  it "basic delete functions" do
    starting_attendees = all_students_in_courses
    
    pete = @ksdbh.select(:Students) {|s| s.student_number == 102}.first.dup
    pete.courses_taken.each {|c| c.delete}
    pete.delete
    
    everyone_but_pete = all_students_in_courses

    ( starting_attendees - everyone_but_pete ).each do |triple|
      lambda do |course, first_name, student_number|
        # Only Pete's classes were deleted
        ['CSC301','LAW101'].must_include course
        first_name.must_equal 'Pete'
        student_number.must_equal 102
      end.call(*triple)
    end
  end

  it "basic delete functions in a transaction" do
    starting_attendees = all_students_in_courses
 
    pete = @ksdbh.select(:Students) {|s| s.student_number == 102}.first.dup
    @ksdbh.transaction do
      pete.courses_taken.each {|c| c.delete}
      pete.delete
    end   
    
    everyone_but_pete = all_students_in_courses

    ( starting_attendees - everyone_but_pete ).each do |triple|
      lambda do |course, first_name, student_number|
        # Only Pete's classes were deleted
        ['CSC301','LAW101'].must_include course
        first_name.must_equal 'Pete'
        student_number.must_equal 102
      end.call(*triple)
    end
  end
  
  it "basic rollback of deletes" do
    starting_attendees = all_students_in_courses
    
    pete = @ksdbh.select(:Students) {|s| s.student_number == 102}.first.dup
    @ksdbh.transaction do
      pete.courses_taken.each {|c| c.delete}
      pete.delete

      # pete is cleared, and changes don't stick.
      pete.student_number.must_equal 0
      pete.student_number = 123
      pete.student_number.must_equal 0
      @ksdbh.rollback
    end   
    pete.student_number.must_equal 102
    
    pete_hasnt_left = all_students_in_courses

    ( starting_attendees - pete_hasnt_left ).must_be_empty
  end
  
  it "use select syntax for deletes" do
    starting_attendees = all_students_in_courses
    
    @ksdbh.delete(:Courses) {|c| c.name == 'XZY987'}
    @ksdbh.delete(:CoursesTaken) {|ct| ct.name == 'XZY987'}
    
    classes_without_xyz987 = all_students_in_courses
    ( starting_attendees - classes_without_xyz987 ).each do |triple|
      lambda do |course, first_name, student_number|
        # They are all XZY987 courses
        course.must_equal "XZY987"
      end.call(*triple)
    end
  end
  
  it "use select syntax for deletes, with transaction and rollback" do
    starting_attendees = all_students_in_courses
    
    @ksdbh.transaction do
      pete = @ksdbh.select(:Students) {|s| s.first_name == 'Pete'}.first.dup
      pete_xzy = @ksdbh.new_object(:CoursesTaken)
      pete_xzy.student_number = pete.student_number
      pete_xzy.name = 'XZY987'
      
      courses_with_pete_in_xzy = all_students_in_courses
      ( courses_with_pete_in_xzy - starting_attendees ).each do |triple|
        lambda do |course, first_name, student_number|
          # Pete's course, only
          course.must_equal "XZY987"
          first_name.must_equal 'Pete'
          student_number.must_equal 102
        end
      end

      @ksdbh.delete(:Courses) {|c| c.name == 'XZY987'}
      @ksdbh.delete(:CoursesTaken) {|ct| ct.name == 'XZY987'}

      courses_without_xzy = all_students_in_courses
      ( starting_attendees - courses_without_xzy ).each do |triple|
        lambda do |course, first_name, student_number|
          # Should all be XZY courses
          course.must_equal "XZY987"
        end
      end

      @ksdbh.rollback
    end
    
    courses_unchanged = all_students_in_courses

  end

end
