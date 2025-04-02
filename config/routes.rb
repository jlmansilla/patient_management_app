Rails.application.routes.draw do
  # Rutas para pacientes
  resources :patients

  # Ruta raíz (ejemplo)
  root "patients#index" # O un dashboard
end
