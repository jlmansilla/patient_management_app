# app/models/patient.rb
class Patient < ApplicationRecord
  # Asociaciones (Ejemplos - descomentar y crear modelos si es necesario)
  # has_many :appointments, dependent: :destroy
  # has_many :medical_records, dependent: :destroy
  # has_one :insurance # Si Insurance es un modelo separado

  # Validaciones
  validates :name, presence: true
  validates :dob, presence: true
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :phone, presence: true

  # Ejemplo de cómo podrías transmitir cambios con Turbo Streams
  # broadcasts_to ->(patient) { "patients" }, inserts_by: :prepend # Para añadir a listas
  # after_update_commit -> { broadcast_replace_to "patients" } # Para actualizar en listas
  # after_destroy_commit -> { broadcast_remove_to "patients" } # Para eliminar de listas
end
