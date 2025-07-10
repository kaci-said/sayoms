# encoding: UTF-8
require 'json'
require_relative 'component_utils'

module LenXYZ
  extend self

  PLUGIN_NAME = "LenXYZ Viewer"

  def show_dlg
    puts "🔧 Plugin '#{PLUGIN_NAME}' lancé"

    dlg = UI::HtmlDialog.new(
      dlg_title: PLUGIN_NAME,
      preferences_key: "lenxyz_viewer",
      style: UI::HtmlDialog::STYLE_DIALOG,
      width: 800,
      height: 600
    )

    plugin_dir = File.dirname(__FILE__)
    html_path = File.join(plugin_dir, "html", "index.html").gsub("\\", "/")
    dlg.set_file(html_path)

    dlg.show
    $lenxyz_dlg = dlg

    start_selection_watcher(dlg)

    # Callback pour recevoir les actions depuis l'HTML
    dlg.add_action_callback("su_action") do |context, action|
      begin
        payload = JSON.parse(action)
        puts "📩 Action reçue : #{payload['type']}"

        case payload["type"]
        when "requestData"
          send_selected_components_data(dlg)
        else
          puts "❓ Type d'action inconnu : #{payload['type']}"
        end

      rescue => e
        puts "❌ Erreur dans su_action : #{e.message}"
        puts e.backtrace
      end
    end
  end

  def send_selected_components_data(dlg)
    components_data = ComponentUtils.get_all_parts_data
    #puts "📄 Données envoyées : #{components_data}"

    dlg.execute_script("updateData(#{components_data})")
  end

  def start_selection_watcher(dlg)
    last_guids = []

    UI.start_timer(2.0, true) do
      model = Sketchup.active_model
      return unless model

      current_selection = model.selection.select { |e| e.is_a?(Sketchup::ComponentInstance) }
      current_guids = current_selection.map(&:guid)

      if current_guids != last_guids
        puts "🔄 Sélection changée – Mise à jour de l'HTML..."
        send_selected_components_data(dlg)
        last_guids = current_guids.dup
      end
    end
  end
end