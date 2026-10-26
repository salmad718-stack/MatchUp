/* ==============================
   Match Up - interactions simples
   ============================== */

document.addEventListener("DOMContentLoaded", function () {
  // Menu mobile
  const menuToggle = document.getElementById("menuToggle");
  const mainNav = document.getElementById("mainNav");

  if (menuToggle && mainNav) {
    menuToggle.addEventListener("click", function () {
      const isOpen = mainNav.classList.toggle("open");
      menuToggle.setAttribute("aria-expanded", String(isOpen));
    });
  }

  // Année automatique dans le pied de page
  const currentYear = document.getElementById("currentYear");
  if (currentYear) {
    currentYear.textContent = new Date().getFullYear();
  }

  // Bouton retour en haut
  const backTop = document.getElementById("backTop");
  if (backTop) {
    window.addEventListener("scroll", function () {
      backTop.classList.toggle("show", window.scrollY > 450);
    });

    backTop.addEventListener("click", function () {
      window.scrollTo({ top: 0, behavior: "smooth" });
    });
  }

  // Filtre des services
  const filterButtons = document.querySelectorAll(".filter-btn");
  const filterItems = document.querySelectorAll(".filter-item");

  if (filterButtons.length && filterItems.length) {
    filterButtons.forEach(function (button) {
      button.addEventListener("click", function () {
        const filter = button.dataset.filter;

        filterButtons.forEach(function (btn) {
          btn.classList.remove("active");
        });
        button.classList.add("active");

        filterItems.forEach(function (item) {
          const category = item.dataset.category;
          item.style.display = filter === "all" || category === filter ? "block" : "none";
        });
      });
    });
  }

  // Validation visuelle du formulaire
    // Formulaire de contact : envoi vers Supabase
  const contactForm = document.getElementById("contactForm");
  const formMessage = document.getElementById("formMessage");

  if (contactForm && formMessage) {
    // Création du client Supabase avec les valeurs de config.js
    const db = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY);

    contactForm.addEventListener("submit", async function (event) {
      event.preventDefault();

      const name = document.getElementById("name").value.trim();
      const email = document.getElementById("email").value.trim();
      const role = document.getElementById("role").value;
      const message = document.getElementById("message").value.trim();

      if (!name || !email || !role || !message) {
        formMessage.textContent = "Veuillez remplir tous les champs obligatoires (*).";
        return;
      }

      const submitButton = contactForm.querySelector("button[type='submit']");
      submitButton.disabled = true;
      formMessage.textContent = "Envoi en cours...";

      // Les noms à gauche sont les colonnes de la table contact_messages
      const { error } = await db.from("contact_messages").insert({
        full_name: name,
        email: email,
        role: role,
        message: message
      });

      submitButton.disabled = false;

      if (error) {
        console.error("Erreur Supabase :", error);
        formMessage.textContent = "Une erreur est survenue. Veuillez réessayer.";
        return;
      }

      formMessage.textContent = "Merci ! Votre message a bien été envoyé.";
      contactForm.reset();
    });
  }
  });
