class CreateUsuariosRoles < ActiveRecord::Migration[5.1]
  def change
    create_table :usuarios_roles do |t|
      t.integer :usuario_id
      t.integer :rol_id

      t.timestamps
    end
  end
end
