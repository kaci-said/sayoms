# encoding: UTF-8

module ComponentUtils
  def self.get_material_type(material)
    return nil unless material
    begin
      mat_attr = Ladb::OpenCutList::MaterialAttributes.new(material)
      mat_attr.type
    rescue => e
      puts "⚠️ Erreur type OpenCutList: #{e.message}"
      nil
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