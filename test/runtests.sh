#!/bin/bash

ruby -I.. TC_NewWithoutDBH.rb
ruby -I.. TC_NewWithDBH.rb
ruby -I.. TC_SelectData.rb
ruby -I.. TC_UpdateData.rb
ruby -I.. TC_InsertData.rb
ruby -I.. TC_DeleteData.rb
ruby -I.. TC_Transactions.rb