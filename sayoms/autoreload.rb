# encoding: UTF-8

PLUGIN_NAME = "LenXYZ Viewer"

# Détection du chemin du plugin
PLUGIN_PATH = nil

begin
  if Sketchup.platform == :platform_win
    appdata = ENV["APPDATA"]
  else
    appdata = File.expand_path("~/.sketchup")
  end

  plugins_dir = File.join(appdata, "SketchUp", "SketchUp 2018", "SketchUp", "Plugins")
  plugin_main_file = File.join(plugins_dir, "lenxyz", "lenxyz.rb")

  if File.exist?(plugin_main_file)
    PLUGIN_PATH = plugin_main_file
  else
    UI.messagebox("Plugin introuvable : #{plugin_main_file}")
    raise SystemExit
  end

  puts "== Auto-reloader activé =="
  puts "Fichier surveillé : #{PLUGIN_PATH}"

  last_mtime = File.mtime(PLUGIN_PATH)

  timer = UI.start_timer(1.0, true) do
    return unless File.exist?(PLUGIN_PATH)

    current_mtime = File.mtime(PLUGIN_PATH)
    if current_mtime > last_mtime
      puts "Changements détectés – Rechargement du plugin..."
      begin
        # Supprime l'ancien menu si présent
        UI.menu("Fenêtre").delete_item(PLUGIN_NAME) rescue nil
        # Recharge le plugin
        load PLUGIN_PATH
        last_mtime = current_mtime
      rescue => e
        puts "Erreur lors du rechargement : #{e.message}"
      end
    end
  end

rescue => e
  puts "Erreur critique : #{e.message}"
  UI.messagebox("Erreur dans l'autoreloader : #{e.message}")
end