class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.integer :conversation_id, null: false
      t.string :sender_type, null: false
      t.text :body, null: false

      t.timestamps
    end
    add_index :messages, :conversation_id
  end
end
