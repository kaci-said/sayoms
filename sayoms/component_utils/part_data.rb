# encoding: UTF-8
require 'sketchup'
require 'json'

module ComponentUtils
  def self.get_all_parts_data
    model = Sketchup.active_model
    return [] unless model

    selection = model.selection.select { |e| e.is_a?(Sketchup::ComponentInstance) }
    puts "🔍 Sélection contient #{selection.size} composant(s)"

    parts = selection.map { |comp| get_part_data(comp) }.compact

    puts "📦 Données envoyées à l'HTML :"
    puts JSON.pretty_generate(parts)
    parts
  end

  def self.get_part_data(component, path = [], parent_component = nil)
  return nil unless component.is_a?(Sketchup::ComponentInstance) && component.valid?

  full_path = (path + [component.definition.name]).join(" > ")
  origin = component.transformation.origin

  data = {
    name: component.definition.name,
    full_path: full_path,
    length: 0.0,
    width: 0.0,
    thickness: 0.0,
    material_name: '',
    material_type: nil,
    tags: [],
    count: component.definition.instances.size,
    origin: {
      x: origin.x.to_l,
      y: origin.y.to_l,
      z: origin.z.to_l
    },
    children: []
  }

  # Récupération des attributs (conservé inchangé)
  dict = component.definition.attribute_dictionary("ladb_opencutlist", false)
  if dict
    data[:material_name] = dict["material"] || ''
    data[:tags] = dict["tags"] || []
  else
    puts "❌ Aucun dictionnaire trouvé pour '#{full_path}'" if ENV['OCL_DEBUG'] == '1'
  end

  # Récupération des attributs dynamiques (conservé inchangé)
  dynamic_attributes = component.definition.attribute_dictionary("dynamic_attributes", false)
  if dynamic_attributes
    data[:dynamic_attributes] = {}
    dynamic_attributes.each_pair do |key, value|
      next if key.to_s.start_with?("_")
      data[:dynamic_attributes][key] = value
    end
  end

  # MODIFICATION CLÉ : Calcul des bounds sur la géométrie native seulement
  native_bounds = Geom::BoundingBox.new
  component.definition.entities.each do |entity|
    if entity.is_a?(Sketchup::Face)
      entity.vertices.each { |v| native_bounds.add(v.position) }
    elsif entity.is_a?(Sketchup::Edge)
      native_bounds.add(entity.start.position)
      native_bounds.add(entity.end.position)
    end
    # On ignore délibérément les sous-composants
  end

  if native_bounds.empty?
    puts "⚠️ Composant '#{full_path}' a des bornes vides." if ENV['OCL_DEBUG'] == '1'
    return data
  end

  # VOTRE LOGIQUE ORIGINALE CONSERVÉE (transformation et projection)
  t = component.transformation
  transformed_points = []
  8.times { |i| transformed_points << native_bounds.corner(i).transform(t) }

  transformed_bbox = Geom::BoundingBox.new
  transformed_points.each { |pt| transformed_bbox.add(pt) }

  size_vector = transformed_bbox.max - transformed_bbox.min
  x_axis = t.xaxis.normalize
  y_axis = t.yaxis.normalize
  z_axis = t.zaxis.normalize

  length     = size_vector.dot(x_axis).abs
  width      = size_vector.dot(y_axis).abs
  thickness  = size_vector.dot(z_axis).abs

  data[:length]     = length.to_l
  data[:width]      = width.to_l
  data[:thickness]  = thickness.to_l

  puts "📏 #{full_path} - L:#{data[:length]} / W:#{data[:width]} / T:#{data[:thickness]}" if ENV['OCL_DEBUG'] == '1'

  # Suite de votre méthode inchangée
  if data[:material_name].empty?
    name, type = detect_main_material(component)
    data[:material_name] = name
    data[:material_type] = type
  else
    data[:material_type] = get_material_type(component.material || component.definition.material)
  end

  if data[:material_type] == 5 && parent_component
    data[:orientation] = detect_orientation(component, parent_component)
  end

  # Traitement récursif des enfants (conservé inchangé)
  component.definition.entities.each do |entity|
    if entity.is_a?(Sketchup::ComponentInstance)
      child_data = get_part_data(entity, path + [component.definition.name], component)
      data[:children] << child_data if child_data
    end
  end

  data
end
end