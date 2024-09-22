class AddVectorColumnToProducts < ActiveRecord::Migration[7.1]
  def change
    # Define the default dimension before the migration runs
    default_dimension = Langchain::LLM::OpenAI.new(api_key: Rails.application.credentials.openai[:api_key]).default_dimension

    add_column :products, :embedding, :vector, limit: default_dimension
  end
end
