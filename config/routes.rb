Rails.application.routes.draw do
  # Asume que Devise está configurado para Users
  devise_for :users

  # Rutas para pacientes
  resources :patients

  # Ruta raíz (ejemplo)
  root "patients#index" # O un dashboard
end
