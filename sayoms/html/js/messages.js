// 📩 Réception des messages du WebDialog (depuis Ruby)
window.addEventListener("message", function(event) {
  const message = event.data;

  // 🧪 Log des données reçues pour debug
  console.log("📦 Données reçues du WebDialog SketchUp:", JSON.stringify(message, null, 2));

  // 📦 Si c'est une mise à jour de données
  if (message.action === "su_action" && message.type === "updateData") {
    if (typeof updateData === "function") {
      updateData(message.data);
    } else {
      console.error("❌ La fonction updateData n'est pas définie !");
    }
  }
});

// 📤 Envoie les dimensions saisies à SketchUp
function sendDimensions() {
  const x = parseFloat(document.getElementById("lenX").value);
  const y = parseFloat(document.getElementById("lenY").value);
  const z = parseFloat(document.getElementById("lenZ").value);

  if (isNaN(x) || isNaN(y) || isNaN(z)) {
    console.warn("⚠️ Dimensions invalides ou incomplètes.");
    return;
  }

  const payload = {
    action: "su_action",
    type: "setDimensions",
    dimensions: { x, y, z }
  };

  console.log("📤 Envoi des dimensions:", payload);
  window.parent.postMessage(payload, "*");
}

// 📤 Demande initiale des données au chargement
function requestComponentData() {
  const request = {
    action: "su_action",
    type: "requestData"
  };

  console.log("📤 Requête initiale de données :", request);
  window.parent.postMessage(request, "*");
}

// ▶️ Exécution au chargement de la page
window.onload = () => {
  requestComponentData();
};
