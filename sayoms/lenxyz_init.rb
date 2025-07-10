# lenxyz_init.rb

require_relative 'lenxyz'

unless file_loaded?("lenxyz.rb")
  UI.menu("Extensions").add_item("LenXYZ Viewer") { LenXYZ.show_dialog }
  file_loaded?("lenxyz.rb")
end
