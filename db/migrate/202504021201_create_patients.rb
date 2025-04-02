class CreatePatients < ActiveRecord::Migration[7.0] # O tu versión de Rails
  def change
    create_table :patients do |t|
      t.string :name
      t.date :dob # Fecha de nacimiento (Date Of Birth)
      t.string :email
      t.string :phone
      t.text :address
      t.string :insurance_policy # Ejemplo simple de póliza

      t.timestamps
    end
    add_index :patients, :email, unique: true # Asegurar email único
  end
end
