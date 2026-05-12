class AddProvenanceDataToBuildingAnalyses < ActiveRecord::Migration[7.0]
  def change
    add_column :building_analyses, :provenance_data, :jsonb
    
    # Add index for querying provenance
    add_index :building_analyses, :provenance_data, name: 'index_building_analyses_on_provenance_data', 
              using: 'gin', opclass: :jsonb_path_ops if ActiveRecord::Base.connection.adapter_name == 'PostgreSQL'
  end
end