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
        x: origin.x.to_l, y: origin.y.to_l, z: origin.z.to_l
      },
      children: []
    }

    dict = component.definition.attribute_dictionary("ladb_opencutlist", false)
    if dict
      data[:material_name] = dict["material"] || ''
      data[:tags] = dict["tags"] || []
    end

    dynamic_attributes = component.definition.attribute_dictionary("dynamic_attributes", false)
    if dynamic_attributes
      data[:dynamic_attributes] = {}
      dynamic_attributes.each_pair do |key, value|
        next if key.to_s.start_with?("_")
        data[:dynamic_attributes][key] = value
      end
    end

    native_bounds = Geom::BoundingBox.new
    component.definition.entities.each do |entity|
      if entity.is_a?(Sketchup::Face)
        entity.vertices.each { |v| native_bounds.add(v.position) }
      elsif entity.is_a?(Sketchup::Edge)
        native_bounds.add(entity.start.position)
        native_bounds.add(entity.end.position)
      end
    end

    return data if native_bounds.empty?

    t = component.transformation
    transformed_bbox = Geom::BoundingBox.new
    8.times { |i| transformed_bbox.add(native_bounds.corner(i).transform(t)) }
    size_vector = transformed_bbox.max - transformed_bbox.min

    data[:length]    = size_vector.dot(t.xaxis.normalize).abs.to_l
    data[:width]     = size_vector.dot(t.yaxis.normalize).abs.to_l
    data[:thickness] = size_vector.dot(t.zaxis.normalize).abs.to_l

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

    if parent_component
      parent_inv = parent_component.transformation.inverse
      local_pos = origin.transform(parent_inv)
      data[:local_position] = {
        x: local_pos.x.to_l, y: local_pos.y.to_l, z: local_pos.z.to_l
      }
    end

    component.definition.entities.each do |entity|
      if entity.is_a?(Sketchup::ComponentInstance)
        child_data = get_part_data(entity, path + [component.definition.name], component)
        data[:children] << child_data if child_data
      end
    end

    data
  end
end