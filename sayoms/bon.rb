# Analyseur d'Orientation Ultime pour Composants Imbriqués
mod = Sketchup.active_model
sel = mod.selection

def analyser_orientation_ultime(parent)
  return unless parent.is_a?(Sketchup::ComponentInstance)
  
  # Préparation des données de référence
  tr_parent = parent.transformation
  axe_parent = {
    x: tr_parent.xaxis,
    y: tr_parent.yaxis, 
    z: tr_parent.zaxis
  }

  # Analyse de chaque sous-composant
  parent.definition.entities.grep(Sketchup::ComponentInstance) do |enfant|
    # Transformation ABSOLUE
    tr_enfant = tr_parent * enfant.transformation
    
    # Calcul des angles avec les 3 axes
    angles = {
      x: tr_enfant.xaxis.angle_between(axe_parent[:x]).radians.round(1),
      y: tr_enfant.xaxis.angle_between(axe_parent[:y]).radians.round(1),
      z: tr_enfant.xaxis.angle_between(axe_parent[:z]).radians.round(1)
    }

    # Détection d'orientation précise
    orientation = case
      when angles[:x] <= 5 || angles[:x] >= 175 then [:longueur, 'X', 0, 255, 0]
      when angles[:y] <= 5 || angles[:y] >= 175 then [:largeur, 'Y', 0, 150, 255]
      when angles[:z] <= 5 || angles[:z] >= 175 then [:hauteur, 'Z', 150, 0, 255]
      else [:oblique, "#{angles.values.min}°", 255, 100, 0]
      end

    # Application visuelle
    enfant.material = orientation[2..4]
    
    # Log de diagnostic
    log = [
      enfant.definition.name.ljust(25),
      "Type: #{orientation[0].to_s.upcase.ljust(8)}",
      "Axe: #{orientation[1].ljust(4)}",
      "Angles: X=#{angles[:x]}° Y=#{angles[:y]}° Z=#{angles[:z]}°"
    ].join(' | ')
    
    puts log
  end
end

# Lancement de l'analyse
if sel.size == 1 && (parent = sel.first).is_a?(Sketchup::ComponentInstance)
  mod.start_operation('Analyse Orientation', true)
  analyser_orientation_ultime(parent)
  mod.commit_operation
  puts "\n=== Analyse terminée ==="
  UI.messagebox("Vérifiez la console Ruby pour les détails complets")
else
  UI.messagebox("ERREUR : Sélectionnez UN SEUL composant parent")
end