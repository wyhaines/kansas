require 'rubygems'
require 'kansas'
require 'dbi'
require 'benchmark'

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
		
@dbh = DBI.connect("dbi:#{@params['vendor']}:#{@params['name']}:#{@params['host']}",@params['user'],@params['password'])

sql = 'create table ltrs (ltr char(1) not null primary key, val int)'
@dbh.do sql

sql = 'create table words (word varchar(255) not null primary key, ltr_idx char(1))'
@dbh.do sql

@ksdbh = KSDatabase.new(@dbh)

@ksdbh.table(:Ltrs,:ltrs)
@ksdbh.table(:Words,:words)
KSDatabase::Ltrs.to_many(:words, :Words, :ltr_idx)

sql = 'insert into ltrs (ltr, val) values (?,?)'
ltr_sth = @dbh.prepare sql
sql = 'insert into words (word, ltr_idx) values (?,?)'
word_sth = @dbh.prepare sql

count = 0

File.open('words') do |fh|
	fh.each_line do |line|
		count += 1
		line.chomp!
		ltr = line[0,1]
		ltr_sth.execute(ltr,0)
		word_sth.execute(line,ltr)
	end
end



Benchmark.bm do |x|
	x.report("dbh select #{count} records") { sql = 'select * from words'
		
