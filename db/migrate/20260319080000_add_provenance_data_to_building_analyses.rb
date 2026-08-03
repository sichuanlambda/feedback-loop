class AddProvenanceDataToBuildingAnalyses < ActiveRecord::Migration[7.0]
  def change
    unless column_exists?(:building_analyses, :provenance_data)
      add_column :building_analyses, :provenance_data, :jsonb
    end

    unless index_exists?(:building_analyses, :provenance_data, name: 'index_building_analyses_on_provenance_data')
      add_index :building_analyses, :provenance_data, name: 'index_building_analyses_on_provenance_data',
                using: 'gin', opclass: :jsonb_path_ops
    end
  end
end