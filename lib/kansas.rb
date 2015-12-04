require 'dbi'
require 'dbi/sql'
require 'kansas/patch_dbi'
require 'kansas/Database'
require 'kansas/Table'
require 'kansas/TableClass'
require 'kansas/ToOne'
require 'kansas/ToMany'
require 'kansas/BelongsTo'
require 'kansas/Expression'

module Kansas
  def Kansas.log(*args)
    $stderr.puts(*args)
  end
end    

KS = Kansas