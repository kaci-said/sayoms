# encoding: UTF-8

module ComponentUtils
  def self.detect_orientation(child, parent)
    return "indéfini" unless child.is_a?(Sketchup::ComponentInstance) && parent.is_a?(Sketchup::ComponentInstance)

    begin
      tr_parent = parent.transformation
      tr_child = parent.transformation * child.transformation

      x_axis = tr_child.xaxis.normalize
      px = tr_parent.xaxis.normalize
      py = tr_parent.yaxis.normalize
      pz = tr_parent.zaxis.normalize

      dx = x_axis.dot(px).abs
      dy = x_axis.dot(py).abs
      dz = x_axis.dot(pz).abs

      if dx > 0.95
        "longueur"
      elsif dy > 0.95
        "largeur"
      elsif dz > 0.95
        "hauteur"
      else
        "oblique"
      end
    rescue => e
      puts "ERREUR dans detect_orientation: #{e.message}"
      "erreur"
    end
  end
end