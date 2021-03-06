class EspecieCatalogoBibliografia < ActiveRecord::Base

  self.table_name = "#{CONFIG.bases.cat}.RelNombreCatalogoBiblio"
  self.primary_keys = :IdNombre, :IdCatNombre, :IdBibliografia

  # Los alias con las tablas de catalogos
  alias_attribute :especie_id, :IdNombre
  alias_attribute :catalogo_id, :IdCatNombre
  alias_attribute :bibliografia_id, :IdBibliografia

end