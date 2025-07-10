# encoding: UTF-8

require 'sketchup'
require 'extensions'

module ComponentUtils
  def self.load_opencutlist
    begin
      require 'ladb_opencutlist'
      puts "✅ OpenCutList chargé"
      return true
    rescue LoadError => e
      puts "⚠️ OpenCutList non chargé : #{e.message}"
      return false
    end
  end

  def self.get_all_parts_data
    model = Sketchup.active_model
    return [].to_json unless model

    selection = model.selection.select { |e| e.is_a?(Sketchup::ComponentInstance) }
    puts "🔍 Sélection contient #{selection.size} composant(s)"

    parts = []

    selection.each do |component|
      part_data = get_part_data(component)
      parts << part_data if part_data
    end

    json_data = parts.to_json
    puts "📦 Données envoyées à l'HTML : #{json_data}"

    json_data
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

    # Récupération des attributs
    dict = component.definition.attribute_dictionary("ladb_opencutlist", false)
    if dict
      data[:material_name] = dict["material"] || ''
      data[:tags] = dict["tags"] || []
    else
      puts "❌ Aucun dictionnaire trouvé pour '#{full_path}'" if ENV['OCL_DEBUG'] == '1'
    end

    # Récupération des attributs dynamiques
    dynamic_attributes = component.definition.attribute_dictionary("dynamic_attributes", false)
    if dynamic_attributes
      data[:dynamic_attributes] = {}
      dynamic_attributes.each_pair do |key, value|
        next if key.to_s.start_with?("_")
        data[:dynamic_attributes][key] = value
      end
    end

    bounds = component.definition.bounds
    if bounds.nil?
      puts "⚠️ Composant '#{full_path}' a des bornes vides." if ENV['OCL_DEBUG'] == '1'
      return data
    end

    # Transformation locale du composant (par rapport au monde)
    t = component.transformation

    # Appliquer la transformation à chaque coin de la bounding box
    transformed_points = []
    8.times { |i| transformed_points << bounds.corner(i).transform(t) }

    # Créer une nouvelle bounding box avec les points transformés
    transformed_bbox = Geom::BoundingBox.new
    transformed_points.each { |pt| transformed_bbox.add(pt) }

    # Taille du composant (vecteur diagonal de la boîte englobante)
    size_vector = transformed_bbox.max - transformed_bbox.min

    # Axes locaux (normalisés)
    x_axis = t.xaxis.normalize
    y_axis = t.yaxis.normalize
    z_axis = t.zaxis.normalize

    # Projections de la taille sur chaque axe local
    length     = size_vector.dot(x_axis).abs
    width      = size_vector.dot(y_axis).abs
    thickness  = size_vector.dot(z_axis).abs

    data[:length]     = length.to_l
    data[:width]      = width.to_l
    data[:thickness]  = thickness.to_l

    puts "📏 #{full_path} - L:#{data[:length]} / W:#{data[:width]} / T:#{data[:thickness]}" if ENV['OCL_DEBUG'] == '1'


    # Détection du matériau principal
    if data[:material_name].empty?
      name, type = detect_main_material(component)
      data[:material_name] = name
      data[:material_type] = type
    else
      data[:material_type] = get_material_type(component.material || component.definition.material)
    end

    # Détection de l'orientation si c'est un matériau de type 5
    if data[:material_type] == 5 && parent_component
      data[:orientation] = detect_orientation(component, parent_component)
    end

    # Traitement récursif des enfants
    component.definition.entities.each do |entity|
      if entity.is_a?(Sketchup::ComponentInstance)
        child_data = get_part_data(entity, path + [component.definition.name], component)
        data[:children] << child_data if child_data
      end
    end

    data
  end

  def self.get_material_type(material)
    return nil unless material
    begin
      mat_attr = Ladb::OpenCutList::MaterialAttributes.new(material)
      return mat_attr.type
    rescue => e
      puts "⚠️ Erreur type OpenCutList: #{e.message}"
      return nil
    end
  end

  def self.detect_orientation(child, parent)
    # Vérification des entrées
    unless child.is_a?(Sketchup::ComponentInstance) && parent.is_a?(Sketchup::ComponentInstance)
      puts "ERREUR: Les arguments doivent être des ComponentInstance"
      return "indéfini"
    end

    begin
      # Transformations globales
      tr_parent = parent.transformation
      tr_child = parent.transformation * child.transformation
      
      # Calcul des angles avec les axes du parent
      angles = {
        x: tr_child.xaxis.angle_between(tr_parent.xaxis).radians.round(1),
        y: tr_child.xaxis.angle_between(tr_parent.yaxis).radians.round(1),
        z: tr_child.xaxis.angle_between(tr_parent.zaxis).radians.round(1)
      }

      # Détection basée sur les mêmes seuils que analyser_orientation_ultime
      case
      when angles[:x] <= 5 || angles[:x] >= 175
        "longueur (X:#{angles[:x]}°)"
      when angles[:y] <= 5 || angles[:y] >= 175
        "largeur (Y:#{angles[:y]}°)"
      when angles[:z] <= 5 || angles[:z] >= 175
        "hauteur (Z:#{angles[:z]}°)"
      else
        "oblique (min:#{angles.values.min}°)"
      end

    rescue => e
      puts "ERREUR dans detect_orientation: #{e.message}"
      "erreur"
    end
  end

  def self.detect_main_material(component)
    material = component.material || component.definition.material
    return ['Matériau inconnu', nil] unless material

    name = material.name.to_s.strip
    name = '(Sans nom)' if name.empty?

    type = nil
    begin
      mat_attr = Ladb::OpenCutList::MaterialAttributes.new(material)
      type = mat_attr.type
    rescue => e
      puts "⚠️ Erreur lors de l’accès au type OpenCutList: #{e.message}"
    end

    [name, type]
  end
end
