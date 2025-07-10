# encoding: UTF-8
require 'sketchup'

module ComponentUtils
  def self.load_opencutlist
    begin
      require 'ladb_opencutlist'
      puts "✅ OpenCutList chargé"
      true
    rescue LoadError => e
      puts "⚠️ OpenCutList non chargé : #{e.message}"
      false
    end
  end
end