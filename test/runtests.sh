#!/bin/bash

ruby -I../lib new_without_dbh_test.rb
ruby -I../lib new_with_dbh_test.rb
ruby -I../lib select_data_test.rb
ruby -I../lib update_data_test.rb
ruby -I../lib insert_data_test.rb
ruby -I../lib delete_data_test.rb
ruby -I../lib transactions_test.rb
