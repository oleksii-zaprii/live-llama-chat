class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations do |t|
      t.string :status, null: false, default: "ai_managed"
      t.string :customer_name
      t.string :customer_email
      t.integer :assigned_agent_id
      t.string :session_token, null: false
      t.datetime :last_activity_at

      t.timestamps
    end
    add_index :conversations, :session_token, unique: true
    add_index :conversations, :status
    add_index :conversations, :assigned_agent_id
  end
end
